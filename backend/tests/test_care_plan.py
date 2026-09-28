"""Care plans: coverage, shape, and the no-medication rule."""
import re

import pytest

from actions import care_plan, scoring, triage
from actions.normalize import normalize_disease

SECTIONS = ("do", "avoid", "red_flags")

# Dosing language has no place anywhere in a care plan: this module exists to
# give guidance a person can act on without a pharmacy, and the advice the app
# shows is the one place a regression would matter most.
DOSING = re.compile(
    r"\b("
    r"\d+\s*mg|milligrams?|dosages?|"
    r"take (?:a|an|one|two|some|\d+) (?:pill|tablet|capsule|dose)"
    r")\b",
    re.IGNORECASE,
)

# Naming a drug is only a problem in a "do" step. Warning someone off one is
# often the most important thing on the card -- paracetamol in liver disease,
# aspirin in dengue and in children -- so the ban applies to instructions to
# act, not to the sections whose whole job is to say what not to do.
DRUG_NAMES = re.compile(
    r"\b("
    r"ibuprofen|paracetamol|acetaminophen|aspirin|amoxicillin|azithromycin|"
    r"metformin|omeprazole|prednisolone|antihistamines?"
    r")\b",
    re.IGNORECASE,
)

# Treatment a clinician already started is the one thing a "do" step may talk
# about, because finishing a course is exactly the advice people most need and
# least follow. It has to read as adherence, though -- never as a suggestion to
# go and start something -- so every such line must say so.
TREATMENT = re.compile(r"\b(antibiotics?|thyroid replacement|course)\b", re.IGNORECASE)
ADHERENCE = re.compile(r"\b(prescribed|as directed|your doctor|care team)\b", re.IGNORECASE)


class TestCoverage:
    def test_every_disease_has_a_plan(self, kb):
        missing = sorted(set(kb.disease_symptoms) - set(care_plan.CARE_PLANS))
        assert missing == []

    def test_no_plans_for_unknown_diseases(self, kb):
        extra = sorted(set(care_plan.CARE_PLANS) - set(kb.disease_symptoms))
        assert extra == []

    def test_keys_are_already_canonical(self):
        """Lookup normalises the query, not the table -- so a key that is not
        itself canonical would simply never be reachable."""
        for key in care_plan.CARE_PLANS:
            assert key == normalize_disease(key)


class TestShape:
    @pytest.mark.parametrize("disease", sorted(care_plan.CARE_PLANS))
    def test_every_plan_is_complete(self, disease):
        plan = care_plan.CARE_PLANS[disease]
        assert plan["goal"].strip()
        for section in SECTIONS:
            assert plan[section], "{} has an empty {}".format(disease, section)
            assert all(item.strip() for item in plan[section])

    def test_default_plan_is_complete(self):
        assert care_plan.DEFAULT_CARE_PLAN["goal"].strip()
        assert all(care_plan.DEFAULT_CARE_PLAN[s] for s in SECTIONS)

    @pytest.mark.parametrize(
        "plan",
        sorted(care_plan.CARE_PLANS) + ["__default__"],
    )
    def test_never_gives_a_dose(self, plan):
        entry = (
            care_plan.DEFAULT_CARE_PLAN
            if plan == "__default__"
            else care_plan.CARE_PLANS[plan]
        )
        for section in SECTIONS:
            for item in entry[section]:
                assert not DOSING.search(item), "{}: {}".format(plan, item)

    @pytest.mark.parametrize(
        "plan",
        sorted(care_plan.CARE_PLANS) + ["__default__"],
    )
    def test_no_do_step_names_a_drug(self, plan):
        entry = (
            care_plan.DEFAULT_CARE_PLAN
            if plan == "__default__"
            else care_plan.CARE_PLANS[plan]
        )
        for item in entry["do"]:
            assert not DRUG_NAMES.search(item), "{}: {}".format(plan, item)

    @pytest.mark.parametrize("plan", sorted(care_plan.CARE_PLANS))
    def test_treatment_steps_are_framed_as_adherence(self, plan):
        for item in care_plan.CARE_PLANS[plan]["do"]:
            if TREATMENT.search(item):
                assert ADHERENCE.search(item), "{}: {}".format(plan, item)


class TestLookup:
    def test_finds_a_plan_from_display_form(self):
        assert care_plan.get_care_plan("Migraine") is care_plan.CARE_PLANS["migraine"]

    def test_unknown_disease_falls_back(self):
        assert care_plan.get_care_plan("not a disease") is care_plan.DEFAULT_CARE_PLAN

    def test_none_falls_back(self):
        assert care_plan.get_care_plan(None) is care_plan.DEFAULT_CARE_PLAN

    def test_flatten_labels_every_section(self):
        lines = care_plan.flatten(care_plan.CARE_PLANS["migraine"])
        assert "Do:" in lines
        assert "Avoid:" in lines
        assert "See a doctor if:" in lines

    def test_flatten_skips_empty_sections(self):
        lines = care_plan.flatten({"do": ["rest"], "avoid": [], "red_flags": []})
        assert lines == ["Do:", "  * rest"]


class TestInResult:
    @pytest.fixture
    def outcome(self, kb):
        state = triage.TriageState()
        for symptom in ("headache", "blurred and distorted vision", "excessive hunger"):
            state.confirm(symptom)
        state.age, state.duration_days, state.severity = 30, 2, 5
        return triage.conclude(kb, state)

    def test_payload_carries_the_plan(self, outcome):
        plan = outcome.messages[0].payload["care_plan"]
        assert plan is care_plan.CARE_PLANS["migraine"]
        assert all(plan[section] for section in SECTIONS)

    def test_transcript_shows_all_three_groups(self, outcome):
        text = outcome.messages[0].text
        assert "What you can do:" in text
        assert "Do:" in text and "Avoid:" in text and "See a doctor if:" in text

    def test_legacy_advice_field_is_unchanged(self, outcome, kb):
        """Older app builds read `advice`; the care plan is added beside it."""
        assert outcome.messages[0].payload["advice"] == kb.advice_for("migraine")

    def test_no_match_result_still_carries_a_plan(self, kb):
        state = triage.TriageState()
        outcome = triage._no_match_outcome(state, [])
        assert outcome.messages[0].payload["care_plan"] is care_plan.DEFAULT_CARE_PLAN

    def test_every_condition_can_be_concluded_with_a_plan(self, kb):
        """The payload must never be missing a plan, whichever condition wins."""
        for disease in sorted(kb.disease_symptoms):
            state = triage.TriageState()
            for symptom in sorted(kb.disease_symptoms[disease])[:4]:
                state.confirm(symptom)
            outcome = triage.conclude(kb, state)
            payload = outcome.messages[0].payload
            assert payload["care_plan"]["goal"]
            assert all(payload["care_plan"][s] for s in SECTIONS)
