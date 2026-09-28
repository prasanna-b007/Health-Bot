"""Dispositions, adaptive stopping and the counterfactual.

The disposition is the part of a result a user can act on, and the part this
engine has the best claim to be right about -- so it is the headline, and
these tests pin its behaviour independently of which condition is named.
"""
import pytest

from actions import scoring, triage


def result_of(kb, state):
    outcome = triage.conclude(kb, state)
    return outcome.messages[0].payload


class TestDispositions:
    def test_every_disposition_is_fully_described(self):
        for code, entry in triage.DISPOSITIONS.items():
            assert entry["label"] and entry["timeframe"] and entry["detail"]

    def test_risk_levels_map_to_dispositions(self):
        assert triage.disposition_for("High") == triage.DISPOSITION_URGENT
        assert triage.disposition_for("Moderate") == triage.DISPOSITION_SOON
        assert triage.disposition_for("Low") == triage.DISPOSITION_SELF_CARE

    def test_an_unknown_level_falls_back_to_the_gentlest_wording(self):
        """Never invent urgency from a value the engine does not recognise."""
        assert triage.disposition_for("banana") == triage.DISPOSITION_SELF_CARE

    def test_emergency_carries_the_emergency_disposition(self):
        payload = triage.emergency_outcome("chest pain").messages[0].payload
        assert payload["disposition"] == triage.DISPOSITION_EMERGENCY

    def test_results_carry_a_disposition(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["high fever", "chills", "headache"]
        payload = result_of(kb, state)
        assert payload["disposition"] in triage.DISPOSITIONS
        assert payload["disposition_label"]
        assert payload["disposition_timeframe"]

    def test_the_disposition_leads_the_rendered_text(self, kb):
        """Someone who reads one line should still know what to do."""
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["high fever", "chills", "headache"]
        outcome = triage.conclude(kb, state)
        first_line = outcome.messages[0].text.splitlines()[0]
        label = triage.DISPOSITIONS[outcome.messages[0].payload["disposition"]]["label"]
        assert label in first_line

    def test_no_match_still_points_somewhere(self, kb):
        state = triage.TriageState(age=30, duration_days=1, severity=2)
        payload = triage._no_match_outcome(state, [])
        assert payload.messages[0].payload["disposition"] in triage.DISPOSITIONS


class TestRiskInteractions:
    def test_severity_and_danger_compound(self):
        """Found by the evaluation suite: 8/10 severity with a high-weight
        symptom reached 55, six points short of High, so a textbook dengue
        presentation was told to see someone within three days."""
        mild = triage.calculate_risk(30, 3, 3, 4)
        severe = triage.calculate_risk(30, 3, 9, 4)
        assert severe.score > mild.score + 10
        assert severe.level == "High"

    def test_prolonged_illness_counts_at_a_vulnerable_age(self):
        young = triage.calculate_risk(30, 30, 5, 2)
        old = triage.calculate_risk(75, 30, 5, 2)
        assert old.score > young.score
        assert "Prolonged illness at a vulnerable age" in old.factors

    def test_a_short_illness_gets_no_duration_credit(self):
        assert "Prolonged illness at a vulnerable age" not in (
            triage.calculate_risk(75, 1, 5, 2).factors
        )

    def test_no_profile_scores_as_before(self):
        """A user with no stored conditions must be unaffected by comorbidity."""
        without = triage.calculate_risk(40, 3, 5, 3)
        with_empty = triage.calculate_risk(40, 3, 5, 3, conditions=[])
        assert without.score == with_empty.score


class TestAdaptiveStopping:
    def test_a_decided_assessment_stops_early(self, kb):
        """Regression: every assessment cost five questions whether or not
        any of them could change the answer."""
        state = triage.TriageState(age=24, duration_days=3, severity=4)
        outcome = triage.start(
            kb, "itching with skin rash and discoloured patches", state)
        state = outcome.state
        turns = 0
        while not outcome.finished and turns < 6:
            if state.pending:
                state.confirm(state.pending)
                state.pending = None
            outcome = triage.advance(kb, state)
            state = outcome.state or state
            turns += 1
        assert state.question_count < triage.MAX_QUESTIONS

    def test_the_question_cap_still_holds(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "I have a headache", state)
        state = outcome.state
        for _ in range(12):
            if outcome.finished:
                break
            if state.pending:
                state.deny(state.pending)
                state.pending = None
            outcome = triage.advance(kb, state)
            state = outcome.state or state
        assert state.question_count <= triage.MAX_QUESTIONS

    def test_a_question_is_never_asked_twice(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        outcome = triage.start(kb, "high fever and headache", state)
        state = outcome.state
        asked = []
        for _ in range(8):
            if outcome.finished or not state.pending:
                break
            asked.append(state.pending)
            state.deny(state.pending)
            state.pending = None
            outcome = triage.advance(kb, state)
            state = outcome.state or state
        assert len(asked) == len(set(asked))


class TestQuestionSelection:
    def test_a_useless_question_scores_low(self, kb):
        scores = scoring.rank(kb, ["itching", "skin rash", "nodal skin eruptions",
                                   "dischromic patches"])
        candidate = scoring.best_question(kb, scores, asked=[])
        assert candidate is None or candidate.value < 0.5

    def test_dangerous_symptoms_are_favoured(self, kb):
        """A yes to chest pain is worth having whatever it does to ranking."""
        scores = scoring.rank(kb, ["cough", "high fever"])
        candidate = scoring.best_question(kb, scores, asked=[])
        assert candidate is not None
        assert candidate.value > 0

    def test_selection_is_deterministic(self, kb):
        scores = scoring.rank(kb, ["high fever", "headache"])
        picks = {
            scoring.next_question_symptom(kb, scores, asked=[])
            for _ in range(10)
        }
        assert len(picks) == 1


class TestCounterfactual:
    def test_a_result_names_what_would_change_it(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=5)
        state.confirmed = ["high fever", "headache"]
        payload = result_of(kb, state)
        changes = payload["changes_answer"]
        if changes is not None:
            assert changes["symptom"] and changes["condition"]

    def test_the_counterfactual_names_a_different_condition(self, kb):
        scores = scoring.rank(kb, ["high fever", "headache"])
        found = scoring.decisive_symptom(kb, scores, asked=[])
        if found is not None:
            symptom, condition = found
            assert condition != scores[0].disease

    def test_an_already_asked_symptom_is_never_offered(self, kb):
        scores = scoring.rank(kb, ["high fever", "headache"])
        pool = [s.disease for s in scores]
        found = scoring.decisive_symptom(kb, scores, asked=["chills", "vomiting"])
        if found is not None:
            assert found[0] not in {"chills", "vomiting"}


class TestUnspecified:
    def test_generic_symptoms_decline_to_name_a_condition(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=3)
        state.confirmed = ["fatigue"]
        payload = result_of(kb, state)
        assert payload["is_unspecified"] is True

    def test_an_unspecified_result_still_advises(self, kb):
        state = triage.TriageState(age=30, duration_days=3, severity=3)
        state.confirmed = ["fatigue"]
        payload = result_of(kb, state)
        assert payload["advice"]
        assert payload["care_plan"]

    def test_distinctive_symptoms_do_name_a_condition(self, kb):
        state = triage.TriageState(age=24, duration_days=5, severity=4)
        state.confirmed = ["itching", "skin rash", "nodal skin eruptions",
                           "dischromic patches"]
        payload = result_of(kb, state)
        assert payload["is_unspecified"] is False
        assert payload["top_condition"] == "Fungal Infection"
