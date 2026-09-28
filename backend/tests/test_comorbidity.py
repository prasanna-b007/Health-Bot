"""Chronic conditions as a risk modifier.

The behaviour these lock down is the one that matters clinically: the same
symptoms must escalate further for someone whose history makes them dangerous,
and must be completely unchanged for someone with no profile at all.
"""
import pytest

from actions import comorbidity, triage
from actions.config import THRESHOLDS


class TestClassify:
    @pytest.mark.parametrize("text,group", [
        ("Asthma", "respiratory"),
        ("COPD", "respiratory"),
        ("type 2 diabetes", "metabolic"),
        ("Diabetes Mellitus", "metabolic"),
        ("high blood pressure", "cardiac"),
        ("chronic kidney disease", "renal"),
        ("undergoing chemotherapy", "immune"),
        ("I am pregnant", "pregnancy"),
    ])
    def test_recognises_common_phrasings(self, text, group):
        assert comorbidity.classify(text) == group

    @pytest.mark.parametrize("text", ["", None, "   ", "mild hayfever", "xyzzy"])
    def test_unrecognised_is_none_not_an_error(self, text):
        # Users type anything. An unknown condition must simply not move the
        # score -- it is never treated as reassurance, and never raises.
        assert comorbidity.classify(text) is None


class TestGrouping:
    def test_two_conditions_in_one_group_count_once(self):
        # Someone listing asthma and COPD is not twice as vulnerable as
        # someone listing one; scoring it that way would let a long profile
        # inflate its own risk level.
        assert comorbidity.groups_for(["Asthma", "COPD"]) == ["respiratory"]

    def test_distinct_groups_are_all_kept(self):
        groups = comorbidity.groups_for(["asthma", "diabetes", "hypertension"])
        assert set(groups) == {"respiratory", "metabolic", "cardiac"}

    def test_unrecognised_entries_are_dropped(self):
        assert comorbidity.groups_for(["xyzzy", "asthma"]) == ["respiratory"]


class TestAssess:
    def test_no_conditions_contributes_nothing(self):
        assert comorbidity.assess([], ["cough"]) == (0, [])
        assert comorbidity.assess(None, None) == (0, [])

    def test_unrecognised_conditions_contribute_nothing(self):
        assert comorbidity.assess(["xyzzy", "mild hayfever"], ["cough"]) == (0, [])

    def test_condition_alone_adds_baseline_only(self):
        score, factors = comorbidity.assess(["asthma"], ["skin rash"])
        assert score == THRESHOLDS["COMORBIDITY_POINTS"]
        assert any("respiratory" in f.lower() for f in factors)

    def test_interaction_adds_more_than_the_condition_alone(self):
        alone, _ = comorbidity.assess(["asthma"], ["skin rash"])
        paired, factors = comorbidity.assess(["asthma"], ["breathlessness"])
        assert paired > alone
        # The reasoning is named, not just scored.
        assert any("breathlessness" in f for f in factors)

    def test_baseline_is_capped(self):
        many = ["asthma", "diabetes", "hypertension", "hiv", "dialysis", "pregnant"]
        score, _ = comorbidity.assess(many, [])
        assert score == THRESHOLDS["COMORBIDITY_MAX"]

    def test_interaction_is_capped(self):
        many = ["asthma", "diabetes", "hypertension", "hiv", "dialysis", "pregnant"]
        score, _ = comorbidity.assess(many, ["breathlessness", "fatigue", "high fever"])
        assert score == (
            THRESHOLDS["COMORBIDITY_MAX"] + THRESHOLDS["COMORBIDITY_INTERACTION_MAX"]
        )

    def test_denied_symptoms_do_not_trigger_interaction(self):
        # assess only ever sees confirmed symptoms; this guards the contract
        # that an empty confirmed list cannot produce an interaction factor.
        score, factors = comorbidity.assess(["asthma"], [])
        assert score == THRESHOLDS["COMORBIDITY_POINTS"]
        assert not any("with" in f for f in factors)


class TestRiskIntegration:
    """The end the user actually feels: the risk level itself."""

    def test_profileless_user_scores_exactly_as_before(self):
        # The regression that matters most -- adding this feature must not
        # move anyone who has no profile.
        without = triage.calculate_risk(30, 3, 5, 3)
        explicit_empty = triage.calculate_risk(
            30, 3, 5, 3, conditions=[], confirmed_symptoms=["cough"]
        )
        assert without.score == explicit_empty.score
        assert without.level == explicit_empty.level

    def test_asthma_with_breathlessness_escalates_the_band(self):
        # The motivating case: identical presentation, different history.
        # Severity 7 and a weight-3 symptom score 40 on their own -- Moderate.
        # Asthma plus a confirmed respiratory symptom carries it to High, which
        # changes the advice from "consult a doctor" to "within 24 hours".
        baseline = triage.calculate_risk(
            40, 3, 7, 3, conditions=[], confirmed_symptoms=["breathlessness"]
        )
        asthmatic = triage.calculate_risk(
            40, 3, 7, 3,
            conditions=["Asthma"],
            confirmed_symptoms=["breathlessness"],
        )
        assert asthmatic.score > baseline.score
        assert baseline.level == "Moderate"
        assert asthmatic.level == "High"

    def test_the_reason_is_shown_to_the_user(self):
        risk = triage.calculate_risk(
            40, 3, 6, 3,
            conditions=["Asthma"],
            confirmed_symptoms=["breathlessness"],
        )
        assert any("breathlessness" in f for f in risk.factors)

    def test_unrelated_condition_does_not_escalate_the_band(self):
        # A condition present but irrelevant to these symptoms adds the
        # baseline only, and must not on its own tip a low presentation.
        risk = triage.calculate_risk(
            30, 1, 2, 1, conditions=["Asthma"], confirmed_symptoms=["skin rash"]
        )
        assert risk.level == "Low"
