"""Negation, history scoping and the split between emergency and crisis.

The cases here are the ones that decide whether this app is safe to hand to
someone. Each failure mode below was real: a negated symptom being confirmed
and escalated, a stroke described in ordinary English sailing past the
detector, and a suicidal disclosure answered with directions to an emergency
department.
"""
import pytest

from actions import emergency, triage
from actions.text_utils import extract_symptoms, negated_symptoms


class TestNegation:
    @pytest.mark.parametrize("text", [
        "no chest pain, just a headache",
        "I do not have chest pain",
        "denies chest pain",
        "I have a headache but no chest pain",
        "never had chest pain",
        "headache without chest pain",
    ])
    def test_denied_red_flags_do_not_escalate(self, text):
        assert emergency.classify_text(text) is None

    @pytest.mark.parametrize("text", [
        "I have crushing chest pain",
        "no fever but severe chest pain",
        "no cough, however my chest hurts badly",
    ])
    def test_negation_does_not_leak_across_clauses(self, text):
        """"no fever but severe chest pain" must still escalate."""
        assert emergency.classify_text(text) is not None

    def test_a_negator_inside_the_phrase_is_not_a_negation(self):
        """"cant breathe" contains "cant". It is a symptom, not a denial."""
        flag = emergency.classify_text("i cant breathe")
        assert flag is not None
        assert flag.category == emergency.CATEGORY_EMERGENCY


class TestNegationInExtraction:
    def test_denied_symptoms_are_not_confirmed(self, kb):
        """Regression: the detector declined to escalate "no chest pain" while
        the extractor confirmed chest pain from the same sentence, which then
        drove ranking, risk and -- being a red flag -- an emergency screen."""
        found = extract_symptoms("no chest pain, just a headache", kb.vocabulary)
        assert "headache" in found
        assert "chest pain" not in found

    def test_denials_are_recoverable_as_evidence(self, kb):
        denied = negated_symptoms("no chest pain, just a headache", kb.vocabulary)
        assert "chest pain" in denied

    def test_an_extracted_denial_does_not_reach_the_red_flag_check(self, kb):
        state = triage.TriageState(age=30, duration_days=2, severity=4)
        triage.start(kb, "no chest pain, but a bad headache", state)
        assert triage.classify_red_flag(None, state) is None


class TestHistory:
    @pytest.mark.parametrize("text", [
        "my father had a heart attack last year",
        "I have a family history of stroke",
        "I used to get chest pain when I was younger",
        "recovered from a stroke years ago",
    ])
    def test_past_events_do_not_escalate(self, text):
        assert emergency.classify_text(text) is None

    @pytest.mark.parametrize("text", [
        "my father is having chest pain right now",
        "my wife cant breathe",
    ])
    def test_someone_else_having_an_emergency_now_still_escalates(self, text):
        """Only the tense is filtered, never the subject.

        A person reaching for a symptom checker on someone else's behalf gets
        the emergency screen. Suppressing third-party reports would have been
        trading a real emergency for a false alarm.
        """
        assert emergency.classify_text(text) is not None

    def test_bare_past_tense_is_not_treated_as_history(self):
        """"I had a seizure" is usually said within the hour."""
        assert emergency.classify_text("I had a seizure") is not None


class TestStrokePhrasing:
    @pytest.mark.parametrize("text", [
        "my speech is slurred and one side feels weak",
        "I have slurred speech",
        "my face is drooping",
        "sudden weakness on one side",
    ])
    def test_stroke_is_caught_in_the_words_people_use(self, text):
        flag = emergency.classify_text(text)
        assert flag is not None
        assert flag.category == emergency.CATEGORY_EMERGENCY


class TestCrisis:
    @pytest.mark.parametrize("text", [
        "i feel suicidal",
        "I want to end my life",
        "I don't want to live anymore",
        "i have been thinking about hurting myself",
        "i took too many pills",
    ])
    def test_crisis_disclosures_are_categorised_separately(self, text):
        flag = emergency.classify_text(text)
        assert flag is not None
        assert flag.is_crisis

    def test_crisis_outranks_a_medical_red_flag_in_the_same_message(self):
        flag = emergency.classify_text("I took an overdose and my chest hurts")
        assert flag.is_crisis

    def test_crisis_response_is_not_the_emergency_department(self):
        outcome = triage.crisis_outcome("suicidal")
        message = outcome.messages[0]
        assert message.payload["category"] == emergency.CATEGORY_CRISIS
        assert message.payload["crisis"] is True
        assert "crisis line" in message.text.lower()

    def test_crisis_never_echoes_the_phrase_back(self):
        """The matched phrase is the most sensitive thing the user typed."""
        outcome = triage.crisis_outcome("kill myself")
        assert outcome.messages[0].payload["reason"] is None

    def test_crisis_still_escalates_for_older_app_builds(self):
        """Clients routing on type == "emergency" must still show a red screen."""
        payload = triage.crisis_outcome("suicidal").messages[0].payload
        assert payload["type"] == "emergency"
        assert payload["emergency"] is True

    def test_crisis_stops_triage(self):
        outcome = triage.crisis_outcome("suicidal")
        assert outcome.finished
        assert outcome.state.confirmed == []


class TestDispatch:
    def test_red_flag_outcome_routes_on_category(self):
        medical = triage.red_flag_outcome(
            emergency.RedFlag("chest pain", emergency.CATEGORY_EMERGENCY))
        crisis = triage.red_flag_outcome(
            emergency.RedFlag("suicidal", emergency.CATEGORY_CRISIS))
        assert medical.messages[0].payload["category"] == "emergency"
        assert crisis.messages[0].payload["category"] == "crisis"

    def test_confirmed_symptoms_are_still_checked(self):
        state = triage.TriageState(confirmed=["chest pain"])
        flag = triage.classify_red_flag(None, state)
        assert flag is not None
        assert flag.category == emergency.CATEGORY_EMERGENCY
