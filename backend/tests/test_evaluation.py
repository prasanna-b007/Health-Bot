"""End-to-end evaluation of the triage engine against vignettes.yml.

Everything else in this suite tests a function. This tests the *answers*: it
replays each vignette through the whole engine the way the action server would
-- red-flag check, free-text extraction, intake, follow-up questions answered
by a simulated patient, scoring, risk, disposition -- and asserts on aggregate
quality rather than on any single case.

That distinction is the point. Unit tests told us the code did what it did;
nothing told us whether a change to priors, smoothing or question selection
made the engine better or worse at the job. It is possible to refactor a
symptom checker into uselessness with every unit test passing, and the only
defence is a measurement that moves when quality moves.

The thresholds below are a floor, not a target. They are set a little under
current measured performance so that ordinary noise does not fail the build
while a real regression does. Raise them when the engine improves; never
lower one to make a red build green without saying why in the commit.

Read tests/vignettes.yml before trusting any of these numbers: the vignettes
are engineering regressions written against the engine's own knowledge base,
not clinical validation.
"""
import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

import pytest
import yaml

from actions import emergency, scoring, triage
from actions.normalize import normalize_disease, normalize_symptom

VIGNETTE_PATH = os.path.join(os.path.dirname(__file__), "vignettes.yml")

# Quality floors. See the module docstring before changing one.
MIN_TOP1_ACCURACY = 0.60
MIN_TOP3_ACCURACY = 0.85
MIN_DISPOSITION_ACCURACY = 0.85
MAX_MEAN_QUESTIONS = 5.0

# Non-negotiable: every vignette marked as a red flag must be caught. A
# symptom checker that misses one chest pain in twenty is not 95% good.
REQUIRED_RED_FLAG_RECALL = 1.0


def load_vignettes() -> List[dict]:
    with open(VIGNETTE_PATH, encoding="utf-8") as handle:
        loaded = yaml.safe_load(handle) or []
    assert loaded, "vignettes.yml is empty"
    identifiers = [v["id"] for v in loaded]
    assert len(identifiers) == len(set(identifiers)), "duplicate vignette id"
    return loaded


VIGNETTES = load_vignettes()


@dataclass
class Replay:
    """What happened when one vignette was run through the engine."""

    vignette: dict
    red_flag: Optional[emergency.RedFlag] = None
    payload: Optional[Dict] = None
    questions_asked: int = 0
    asked_symptoms: List[str] = field(default_factory=list)

    @property
    def identifier(self) -> str:
        return self.vignette["id"]

    @property
    def is_emergency(self) -> bool:
        return self.red_flag is not None and not self.red_flag.is_crisis

    @property
    def is_crisis(self) -> bool:
        return self.red_flag is not None and self.red_flag.is_crisis

    @property
    def is_clarification(self) -> bool:
        return bool(self.payload) and self.payload.get("type") == "clarification"

    @property
    def top_conditions(self) -> List[str]:
        """Leading condition first, then alternatives, as canonical keys."""
        if not self.payload or self.payload.get("type") != "result":
            return []
        names = []
        top = self.payload.get("top_condition")
        if top and not self.payload.get("is_unspecified"):
            names.append(normalize_disease(top))
        for alternative in self.payload.get("alternatives") or []:
            names.append(normalize_disease(alternative.get("name", "")))
        return [name for name in names if name]


def replay(kb, vignette: dict, max_turns: int = 12) -> Replay:
    """Run one vignette through the engine as the action server would.

    The simulated patient answers every follow-up question truthfully from the
    vignette's `symptoms` list: present means yes, absent means no. Nobody
    answers "not sure", which makes this an optimistic estimate of question
    efficiency and an honest one of accuracy.
    """
    result = Replay(vignette=vignette)
    has = {normalize_symptom(s) for s in vignette.get("symptoms") or []}

    state = triage.TriageState(
        age=vignette.get("age"),
        duration_days=vignette.get("duration_days"),
        severity=vignette.get("severity"),
    )

    # The adapter checks for red flags before anything else touches the text.
    flag = triage.classify_red_flag(vignette["text"], state)
    if flag is not None:
        result.red_flag = flag
        return result

    outcome = triage.start(kb, vignette["text"], state)

    for _ in range(max_turns):
        state = outcome.state or state
        message = outcome.messages[0]
        result.payload = message.payload or {}

        # Confirming a symptom can itself be a red flag, exactly as in
        # actions.py, so the same check runs after every state change.
        flag = triage.classify_red_flag(None, state)
        if flag is not None:
            result.red_flag = flag
            return result

        if outcome.finished or result.payload.get("type") in {"result", "clarification"}:
            return result

        pending = state.pending
        if not pending:
            return result

        result.questions_asked += 1
        result.asked_symptoms.append(pending)
        if normalize_symptom(pending) in has:
            state.confirm(pending)
        else:
            state.deny(pending)
        state.pending = None
        outcome = triage.advance(kb, state)

    pytest.fail("vignette {} did not conclude in {} turns".format(
        vignette["id"], max_turns))


@pytest.fixture(scope="module")
def replays(kb) -> List[Replay]:
    return [replay(kb, vignette) for vignette in VIGNETTES]


# ---------------------------------------------------------------------------
# Per-vignette expectations
# ---------------------------------------------------------------------------
# Each list is filtered to the vignettes that actually declare the
# expectation, so the suite reports the checks it ran rather than burying
# them in a hundred skips.
def _with(*keys) -> List[dict]:
    return [v for v in VIGNETTES if any(v.get(key) is not None for key in keys)]


def _ids(vignettes: List[dict]) -> List[str]:
    return [v["id"] for v in vignettes]


_RED_FLAG = _with("expect_emergency", "expect_crisis")
_UNSPECIFIED = _with("expect_unspecified")
_CLARIFICATION = _with("expect_clarification")


@pytest.mark.parametrize("vignette", _RED_FLAG, ids=_ids(_RED_FLAG))
def test_red_flag_expectation(kb, vignette):
    outcome = replay(kb, vignette)
    if vignette.get("expect_emergency"):
        assert outcome.is_emergency, "red flag missed"
    if vignette.get("expect_crisis"):
        assert outcome.is_crisis, "crisis routed as a medical emergency"
    if vignette.get("expect_emergency") is False:
        assert not outcome.is_emergency, (
            "false emergency on: {!r}".format(vignette["text"])
        )


@pytest.mark.parametrize("vignette", _RED_FLAG, ids=_ids(_RED_FLAG))
def test_an_escalation_never_also_diagnoses(kb, vignette):
    outcome = replay(kb, vignette)
    if outcome.red_flag is None:
        return
    assert outcome.payload is None or outcome.payload.get("type") != "result"


@pytest.mark.parametrize("vignette", _UNSPECIFIED, ids=_ids(_UNSPECIFIED))
def test_declines_to_name_when_it_should(kb, vignette):
    assert replay(kb, vignette).payload.get("is_unspecified") is True


@pytest.mark.parametrize("vignette", _CLARIFICATION, ids=_ids(_CLARIFICATION))
def test_asks_for_a_rephrase_when_nothing_is_recognised(kb, vignette):
    assert replay(kb, vignette).is_clarification


# ---------------------------------------------------------------------------
# Aggregate quality
# ---------------------------------------------------------------------------
def _scored(replays: List[Replay], key: str) -> List[Replay]:
    return [r for r in replays if r.vignette.get(key) or r.vignette.get("expect_top3")]


class TestAggregateQuality:
    def test_red_flag_recall_is_total(self, replays):
        expected = [
            r for r in replays
            if r.vignette.get("expect_emergency") or r.vignette.get("expect_crisis")
        ]
        caught = [r for r in expected if r.red_flag is not None]
        recall = len(caught) / len(expected)
        assert recall >= REQUIRED_RED_FLAG_RECALL, "missed: {}".format(
            [r.identifier for r in expected if r.red_flag is None]
        )

    def test_no_false_emergencies(self, replays):
        """Precision matters too: an app that cries wolf gets uninstalled."""
        false_alarms = [
            r.identifier for r in replays
            if r.red_flag is not None
            and not r.vignette.get("expect_emergency")
            and not r.vignette.get("expect_crisis")
        ]
        assert not false_alarms, "false emergencies: {}".format(false_alarms)

    def test_top1_accuracy(self, replays):
        graded = [r for r in replays if r.vignette.get("expect_condition")]
        hits = [
            r for r in graded
            if r.top_conditions
            and r.top_conditions[0] == normalize_disease(r.vignette["expect_condition"])
        ]
        accuracy = len(hits) / len(graded)
        misses = [
            "{}: got {}".format(r.identifier, (r.top_conditions or ["-"])[0])
            for r in graded if r not in hits
        ]
        assert accuracy >= MIN_TOP1_ACCURACY, (
            "top-1 {:.0%} over {} vignettes; {}".format(accuracy, len(graded), misses)
        )

    def test_top3_accuracy(self, replays):
        graded = [
            r for r in replays
            if r.vignette.get("expect_condition") or r.vignette.get("expect_top3")
        ]
        hits = []
        for r in graded:
            acceptable = {
                normalize_disease(d)
                for d in (r.vignette.get("expect_top3")
                          or [r.vignette["expect_condition"]])
            }
            if set(r.top_conditions[:3]) & acceptable:
                hits.append(r)
        accuracy = len(hits) / len(graded)
        misses = [r.identifier for r in graded if r not in hits]
        assert accuracy >= MIN_TOP3_ACCURACY, (
            "top-3 {:.0%} over {} vignettes; missed {}".format(
                accuracy, len(graded), misses)
        )

    def test_disposition_accuracy(self, replays):
        graded = [r for r in replays if r.vignette.get("expect_disposition")]
        hits = [
            r for r in graded
            if (r.payload or {}).get("disposition") == r.vignette["expect_disposition"]
            or (r.is_emergency and r.vignette["expect_disposition"] == "emergency")
        ]
        accuracy = len(hits) / len(graded)
        misses = [
            "{}: wanted {} got {}".format(
                r.identifier, r.vignette["expect_disposition"],
                (r.payload or {}).get("disposition"))
            for r in graded if r not in hits
        ]
        assert accuracy >= MIN_DISPOSITION_ACCURACY, (
            "disposition {:.0%} over {} vignettes; {}".format(
                accuracy, len(graded), misses)
        )

    def test_questions_stay_within_budget(self, replays):
        asked = [r.questions_asked for r in replays if r.red_flag is None]
        mean = sum(asked) / len(asked)
        assert max(asked) <= triage.MAX_QUESTIONS, "exceeded the question cap"
        assert mean <= MAX_MEAN_QUESTIONS, (
            "mean {:.1f} questions per assessment".format(mean)
        )

    def test_every_result_carries_a_disposition(self, replays):
        for r in replays:
            if not r.payload or r.payload.get("type") != "result":
                continue
            assert r.payload.get("disposition") in triage.DISPOSITIONS, r.identifier
            assert r.payload.get("disposition_label"), r.identifier

    def test_no_question_is_asked_twice(self, replays):
        for r in replays:
            assert len(r.asked_symptoms) == len(set(r.asked_symptoms)), r.identifier


def test_report(replays, capsys):
    """Not an assertion -- prints the scorecard. `pytest -s` to read it."""
    lines = ["", "Triage evaluation ({} vignettes)".format(len(replays)), "-" * 52]
    for r in replays:
        if r.red_flag is not None:
            verdict = "CRISIS" if r.is_crisis else "EMERGENCY"
        elif r.is_clarification:
            verdict = "rephrase"
        elif r.payload and r.payload.get("is_unspecified"):
            verdict = "unspecified"
        else:
            verdict = (r.top_conditions or ["-"])[0]
        lines.append("{:<34} {:>2}q  {}".format(
            r.identifier, r.questions_asked, verdict[:30]))
    with capsys.disabled():
        print("\n".join(lines))
