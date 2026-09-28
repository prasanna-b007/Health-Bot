"""The conversation state machine, end to end, with no action server."""
import pytest

from actions import scoring, triage
from actions.config import THRESHOLDS


def answer_intake(kb, state, age=30, duration=3, severity=5):
    """Walk the age/duration/severity intake questions."""
    for value, attribute in ((age, "age"), (duration, "duration_days"),
                             (severity, "severity")):
        setattr(state, attribute, value)
    return triage.advance(kb, state)


def result_payload(outcome):
    for message in outcome.messages:
        if message.payload and message.payload.get("type") == "result":
            return message.payload
    return None


class TestState:
    def test_confirm_then_deny_keeps_the_confirmation(self):
        state = triage.TriageState()
        state.confirm("high fever")
        state.deny("high fever")
        assert state.confirmed == ["high fever"]
        assert state.denied == []

    def test_deny_then_confirm_flips_it(self):
        state = triage.TriageState()
        state.deny("high fever")
        state.confirm("high fever")
        assert state.confirmed == ["high fever"]
        assert state.denied == []

    def test_answers_are_normalised(self):
        state = triage.TriageState()
        state.confirm("Skin_Rash")
        assert state.confirmed == ["skin rash"]

    def test_every_answer_counts_as_asked(self):
        state = triage.TriageState()
        state.confirm("high fever")
        state.deny("cough")
        state.mark_unknown("nausea")
        assert set(state.asked) == {"high fever", "cough", "nausea"}

    def test_unsure_is_not_evidence(self):
        state = triage.TriageState()
        state.confirm("high fever")
        state.mark_unknown("cough")
        assert state.evidence_count == 1


class TestIntake:
    def test_age_is_asked_first(self, kb):
        outcome = triage.start(kb, "I have fever and headache")
        assert outcome.state.stage == triage.STAGE_AGE
        assert outcome.messages[0].payload["input_type"] == "number"

    def test_intake_runs_in_order(self, kb):
        state = triage.start(kb, "I have fever and headache").state
        state.age = 30
        assert triage.advance(kb, state).state.stage == triage.STAGE_DURATION
        state.duration_days = 3
        assert triage.advance(kb, state).state.stage == triage.STAGE_SEVERITY

    def test_metadata_skips_intake(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "I have fever and headache", state)
        assert outcome.state.stage is None
        assert outcome.messages[0].payload["type"] in {"question", "result"}

    def test_unrecognised_symptoms_ask_for_a_rephrase(self, kb):
        outcome = triage.start(kb, "I feel a bit off today")
        assert outcome.messages[0].payload["type"] == "clarification"
        assert outcome.state.confirmed == []


class TestQuestioning:
    def test_follow_up_is_a_yes_no_question(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "I have fever", state)
        payload = outcome.messages[0].payload
        assert payload["type"] == "question"
        assert payload["input_type"] == "yes_no"
        assert payload["question_number"] == 1
        assert payload["reason"]

    def test_question_wording_is_deterministic(self, kb):
        assert triage.followup_question("chills") == triage.followup_question("chills")

    def test_questions_stop_at_the_cap(self, kb):
        """Regression: the counter was reset on every new message, so the cap
        was unreachable and questioning could continue indefinitely."""
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "I have a headache", state)
        for _ in range(triage.MAX_QUESTIONS + 3):
            if outcome.finished:
                break
            pending = outcome.state.pending
            assert pending is not None
            outcome.state.deny(pending)
            outcome.state.pending = None
            outcome = triage.advance(kb, outcome.state)
        assert outcome.finished
        assert outcome.messages[0].payload["type"] == "result"

    def test_a_symptom_is_never_asked_twice(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "I have a headache", state)
        seen = []
        while not outcome.finished and outcome.state.pending:
            assert outcome.state.pending not in seen
            seen.append(outcome.state.pending)
            outcome.state.confirm(outcome.state.pending)
            outcome.state.pending = None
            outcome = triage.advance(kb, outcome.state)


class TestConclusion:
    def test_strong_evidence_produces_a_result(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["itching", "skin rash", "nodal skin eruptions"]
        payload = result_payload(triage.conclude(kb, state))
        assert payload["top_condition"] == "Fungal Infection"
        assert payload["confidence_band"] == scoring.BAND_LIKELY
        assert payload["specialist"]["department"] == "Dermatology"

    def test_result_carries_the_disclaimer(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["itching", "skin rash", "nodal skin eruptions"]
        outcome = triage.conclude(kb, state)
        assert result_payload(outcome)["disclaimer"]
        assert "not a medical diagnosis" in outcome.messages[0].text

    def test_weak_evidence_declines_to_name_a_condition(self, kb):
        """A single unrevealing symptom must not produce a named condition.

        It used to fall through to the no-match path; now the ranker has an
        explicit "none of these" candidate and that candidate wins outright,
        which is the same refusal arrived at honestly.
        """
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["fatigue"]
        payload = result_payload(triage.conclude(kb, state))
        assert payload["is_unspecified"] is True
        assert payload["top_condition"] == scoring.OTHER_DISPLAY

    def test_advice_is_condition_specific(self, kb):
        """Regression: every disease received the same five generic strings
        because the filtered per-disease list was built and then discarded."""
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["itching", "skin rash", "nodal skin eruptions"]
        fungal = result_payload(triage.conclude(kb, state))["advice"]
        assert fungal != kb.GENERAL_ADVICE if hasattr(kb, "GENERAL_ADVICE") else True
        from actions.datastore import GENERAL_ADVICE
        assert fungal[: len(GENERAL_ADVICE)] != GENERAL_ADVICE
        assert all(item in fungal for item in GENERAL_ADVICE)

    def test_advice_never_prescribes_treatment(self, kb):
        banned = ("antibiotic", "aspirin", "medication", "surgery", "vaccine")
        for disease in kb.disease_symptoms:
            for item in kb.advice_for(disease):
                assert not any(term in item.lower() for term in banned), \
                    "{} advises: {}".format(disease, item)

    def test_alternatives_shrink_as_confidence_grows(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["itching", "skin rash", "nodal skin eruptions"]
        confident = result_payload(triage.conclude(kb, state))
        assert confident["alternatives"] == []

    def test_denied_symptoms_are_reported(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["itching", "skin rash", "nodal skin eruptions"]
        state.denied = ["cough"]
        assert result_payload(triage.conclude(kb, state))["ruled_out_symptoms"] == ["Cough"]

    def test_conclusion_clears_the_assessment(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["itching", "skin rash"]
        outcome = triage.conclude(kb, state)
        assert outcome.state.confirmed == []
        assert outcome.state.stage == triage.STAGE_FEEDBACK
        assert outcome.state.age is None


class TestRisk:
    def test_low_risk_baseline(self):
        risk = triage.calculate_risk(age=30, duration_days=1, severity=2, max_symptom_weight=1)
        assert risk.level == "Low"

    def test_severe_symptoms_raise_risk(self):
        risk = triage.calculate_risk(age=30, duration_days=1, severity=9, max_symptom_weight=5)
        assert risk.level == "High"

    def test_infants_carry_extra_risk(self):
        baseline = triage.calculate_risk(30, 3, 5, 3)
        infant = triage.calculate_risk(1, 3, 5, 3)
        assert infant.score > baseline.score
        assert "Infant vulnerability" in infant.factors

    def test_age_threshold_matches_config(self):
        boundary = THRESHOLDS["AGE_RISK"]
        below = triage.calculate_risk(boundary - 1, 3, 5, 3)
        at = triage.calculate_risk(boundary, 3, 5, 3)
        assert "Age-related vulnerability" not in below.factors
        assert "Age-related vulnerability" in at.factors

    def test_missing_inputs_do_not_crash(self):
        risk = triage.calculate_risk(None, None, None, 1)
        assert risk.level in {"Low", "Moderate", "High"}
        assert risk.factors

    def test_disposition_tracks_level(self):
        high = triage.calculate_risk(70, 10, 9, 5)
        low = triage.calculate_risk(30, 1, 1, 1)
        assert high.level == "High"
        assert high.disposition == triage.DISPOSITION_URGENT
        assert low.disposition == triage.DISPOSITION_SELF_CARE
        # recommended_action is still populated for older app builds.
        assert high.recommended_action
        assert low.recommended_action != high.recommended_action


class TestEmergencyIntegration:
    def test_red_flag_in_text_short_circuits(self, kb):
        assert triage.check_emergency("I can't breathe") is not None

    def test_red_flag_among_confirmed_symptoms(self, kb):
        state = triage.TriageState(confirmed=["chest pain"])
        assert triage.check_emergency("yes", state) is not None

    def test_emergency_outcome_clears_state(self):
        outcome = triage.emergency_outcome("chest pain")
        assert outcome.finished
        assert outcome.state.confirmed == []
        assert outcome.messages[0].payload["emergency"] is True

    def test_free_text_red_flag_reaches_the_confirmed_list(self, kb):
        """A user typing chest pain must be catchable via the symptom path too."""
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "I have chest pain and cough", state)
        assert triage.check_emergency(None, outcome.state) is not None


class TestFullConversation:
    def test_a_complete_assessment_reaches_a_result(self, kb):
        outcome = triage.start(kb, "I have fever and headache")
        assert outcome.state.stage == triage.STAGE_AGE
        outcome = answer_intake(kb, outcome.state, age=28, duration=4, severity=6)

        guard = 0
        while not outcome.finished:
            guard += 1
            assert guard < 20, "conversation did not terminate"
            pending = outcome.state.pending
            assert pending is not None
            outcome.state.confirm(pending)
            outcome.state.pending = None
            outcome = triage.advance(kb, outcome.state)

        payload = result_payload(outcome)
        assert payload is not None
        assert payload["risk"] in {"low", "moderate", "high"}
        assert payload["matched_symptoms"]

    def test_answering_no_to_everything_still_terminates(self, kb):
        outcome = triage.start(kb, "I have a cough")
        outcome = answer_intake(kb, outcome.state)
        guard = 0
        while not outcome.finished:
            guard += 1
            assert guard < 20, "conversation did not terminate"
            if outcome.state.pending:
                outcome.state.deny(outcome.state.pending)
                outcome.state.pending = None
            outcome = triage.advance(kb, outcome.state)
        assert result_payload(outcome) is not None

    def test_unsure_answers_do_not_stall_the_conversation(self, kb):
        outcome = triage.start(kb, "I have a headache")
        outcome = answer_intake(kb, outcome.state)
        guard = 0
        while not outcome.finished:
            guard += 1
            assert guard < 20, "conversation did not terminate"
            if outcome.state.pending:
                outcome.state.mark_unknown(outcome.state.pending)
                outcome.state.pending = None
            outcome = triage.advance(kb, outcome.state)
        assert result_payload(outcome) is not None
