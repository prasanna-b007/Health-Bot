"""The triage engine.

Deliberately free of any Rasa import. The conversation is a state machine over
a plain dataclass, so the whole decision path -- what to ask next, when to stop,
what to conclude -- can be exercised in unit tests with no action server, no
tracker and no network. actions.py is a thin adapter that moves values between
Rasa slots and TriageState.
"""
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from . import care_plan, comorbidity, emergency, scoring
from .config import THRESHOLDS
from .datastore import KnowledgeBase
from .normalize import display, normalize_symptom
from .reason_map import DEFAULT_REASON, REASON_MAP
from .specialists import get_specialist
from .text_utils import dedupe, extract_symptoms

logger = logging.getLogger(__name__)

DISCLAIMER = (
    "\n\n_This is not a medical diagnosis. Please consult a qualified "
    "healthcare professional._"
)

MIN_SYMPTOMS_TO_CONCLUDE = 2
MAX_QUESTIONS = 5

# Questions below this many are always worth asking: two answers is the least
# that makes a conclusion meaningful, and stopping earlier than that on an
# information argument produces a confident result from almost no evidence.
MIN_QUESTIONS = 2

# Conversation stages that are waiting on a specific answer.
STAGE_AGE = "asking_age"
STAGE_DURATION = "asking_duration"
STAGE_SEVERITY = "asking_severity"
STAGE_FEEDBACK = "asking_feedback"

# Chosen by symptom name rather than at random, so an identical session
# produces identical wording -- regression tests could not assert on output
# while the phrasing was drawn from random.choice.
_FOLLOWUP_TEMPLATES = (
    "To help narrow this down, are you also dealing with **{symptom}**?",
    "Just to confirm, are you experiencing **{symptom}** as well?",
    "Let me check one more thing — do you also have **{symptom}**?",
    "Are you also noticing any **{symptom}**?",
    "To better assess your condition, do you have **{symptom}**?",
)


def followup_question(symptom: str) -> str:
    key = normalize_symptom(symptom)
    index = sum(ord(c) for c in key) % len(_FOLLOWUP_TEMPLATES)
    return _FOLLOWUP_TEMPLATES[index].format(symptom=display(key))


def question_reason(symptom: str) -> str:
    return REASON_MAP.get(normalize_symptom(symptom).replace(" ", "_"), DEFAULT_REASON)


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
@dataclass
class TriageState:
    """Everything the engine needs to decide the next move."""

    confirmed: List[str] = field(default_factory=list)
    denied: List[str] = field(default_factory=list)
    unknown: List[str] = field(default_factory=list)
    asked: List[str] = field(default_factory=list)
    pending: Optional[str] = None
    question_count: int = 0
    age: Optional[int] = None
    duration_days: Optional[int] = None
    severity: Optional[int] = None
    stage: Optional[str] = None

    # Ongoing conditions supplied by the app's stored profile. Free text, as
    # the user typed it; comorbidity.py decides what it recognises. Unlike the
    # intake values these are never asked for conversationally -- an empty list
    # simply means the user has no profile, which must score as it always did.
    conditions: List[str] = field(default_factory=list)

    def confirm(self, symptom: str) -> None:
        key = normalize_symptom(symptom)
        if key and key not in self.confirmed:
            self.confirmed.append(key)
        self._forget(self.denied, key)
        self._forget(self.unknown, key)
        self.mark_asked(key)

    def deny(self, symptom: str) -> None:
        key = normalize_symptom(symptom)
        if key and key not in self.denied and key not in self.confirmed:
            self.denied.append(key)
        self._forget(self.unknown, key)
        self.mark_asked(key)

    def mark_unknown(self, symptom: str) -> None:
        key = normalize_symptom(symptom)
        if key and key not in self.unknown and key not in self.confirmed:
            self.unknown.append(key)
        self.mark_asked(key)

    def mark_asked(self, symptom: str) -> None:
        key = normalize_symptom(symptom)
        if key and key not in self.asked:
            self.asked.append(key)

    @staticmethod
    def _forget(bucket: List[str], key: str) -> None:
        if key in bucket:
            bucket.remove(key)

    @property
    def evidence_count(self) -> int:
        """Answers that carry information -- "not sure" does not."""
        return len(self.confirmed) + len(self.denied)


@dataclass
class BotMessage:
    """One outbound message: markdown text plus the structured payload."""

    text: str
    payload: Optional[Dict[str, Any]] = None


@dataclass
class Outcome:
    messages: List[BotMessage] = field(default_factory=list)
    state: Optional[TriageState] = None
    finished: bool = False


# ---------------------------------------------------------------------------
# Risk
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Disposition
# ---------------------------------------------------------------------------
# What the user should actually *do*, which is the only part of an assessment
# they can act on. This is now the headline of the result and the condition
# name is the supporting detail, reversing the previous emphasis.
#
# The reason is not presentational. Naming a condition from 41 possibilities
# and a teaching dataset is the least reliable thing this engine does; working
# out whether someone should be seen today, this week, or not at all is the
# most reliable, because it rests on symptom severity, age, duration and
# comorbidity rather than on pattern-matching a diagnosis. Leading with the
# disposition puts the confident half of the answer first. It is also what
# triage protocols are validated against, which a disease guess is not.
DISPOSITION_EMERGENCY = "emergency"
DISPOSITION_URGENT = "urgent_today"
DISPOSITION_SOON = "see_doctor_soon"
DISPOSITION_SELF_CARE = "self_care"

DISPOSITIONS = {
    DISPOSITION_EMERGENCY: {
        "label": "Emergency care now",
        "timeframe": "Now",
        "detail": "Call your local emergency number or go to the nearest "
                  "emergency department.",
    },
    DISPOSITION_URGENT: {
        "label": "Urgent care today",
        "timeframe": "Within 24 hours",
        "detail": "See a doctor today, or go to an urgent care centre if you "
                  "cannot get an appointment.",
    },
    DISPOSITION_SOON: {
        "label": "See a doctor soon",
        "timeframe": "Within 72 hours",
        "detail": "Book an appointment with a doctor in the next few days, "
                  "and sooner if anything worsens.",
    },
    DISPOSITION_SELF_CARE: {
        "label": "Self-care and monitor",
        "timeframe": "Monitor at home",
        "detail": "Rest, stay hydrated, and see a doctor if symptoms persist "
                  "beyond a few days or get worse.",
    },
}

_RISK_DISPOSITIONS = {
    "High": DISPOSITION_URGENT,
    "Moderate": DISPOSITION_SOON,
    "Low": DISPOSITION_SELF_CARE,
}


def disposition_for(risk_level: str) -> str:
    """The disposition a risk level calls for."""
    return _RISK_DISPOSITIONS.get(risk_level, DISPOSITION_SELF_CARE)


def disposition_payload(code: str) -> Dict[str, Any]:
    entry = DISPOSITIONS.get(code, DISPOSITIONS[DISPOSITION_SELF_CARE])
    return {
        "disposition": code,
        "disposition_label": entry["label"],
        "disposition_timeframe": entry["timeframe"],
        "disposition_detail": entry["detail"],
    }


@dataclass
class RiskAssessment:
    level: str
    score: int
    factors: List[str]

    @property
    def disposition(self) -> str:
        return disposition_for(self.level)

    @property
    def recommended_action(self) -> str:
        """Kept for older app builds, which read this string directly."""
        return DISPOSITIONS[self.disposition]["detail"]


def calculate_risk(
    age: Optional[int],
    duration_days: Optional[int],
    severity: Optional[int],
    max_symptom_weight: int,
    conditions: Optional[List[str]] = None,
    confirmed_symptoms: Optional[List[str]] = None,
) -> RiskAssessment:
    """Blend reported severity, age, symptom danger, duration and history.

    max_symptom_weight comes from Symptom-severity.csv, which is the single
    source of truth for how dangerous a symptom is. Disease matching uses
    case frequencies instead (see scoring.py) -- the two were previously
    conflated across two disagreeing weight tables.

    conditions and confirmed_symptoms are optional and default to no
    contribution, so every existing caller -- and any user without a stored
    profile -- scores exactly as before.
    """
    factors: List[str] = []
    score = 0

    reported = severity if severity is not None else 1
    if reported >= THRESHOLDS["SEVERITY_HIGH"]:
        score += 25
        factors.append("High symptom severity ({}/10)".format(reported))
    elif reported >= THRESHOLDS["SEVERITY_MODERATE"]:
        score += 15
        factors.append("Moderate symptom severity ({}/10)".format(reported))
    else:
        score += 5

    years = age if age is not None else 30
    if years <= THRESHOLDS["AGE_INFANT"]:
        score += 25
        factors.append("Infant vulnerability")
    elif years <= THRESHOLDS["AGE_CHILD"]:
        score += 5
        factors.append("Child vulnerability")
    elif years >= THRESHOLDS["AGE_RISK"]:
        score += 20
        factors.append("Age-related vulnerability")

    if max_symptom_weight >= 4:
        score += 30
        factors.append("High risk symptoms present")
    elif max_symptom_weight == 3:
        score += 15
        factors.append("Moderate risk symptoms present")
    elif max_symptom_weight == 2:
        score += 5

    days = duration_days if duration_days is not None else 1
    if days >= THRESHOLDS["DURATION_RISK_DAYS"] and max_symptom_weight >= 3:
        score += 15
        factors.append("Prolonged concerning symptom ({} days)".format(days))
    elif days <= THRESHOLDS["DURATION_ACUTE_DAYS"] and max_symptom_weight >= 4:
        score += 15
        factors.append("Acute onset of severe symptom")

    # Interactions. Each of these is a combination that is worse than the sum
    # of its parts, and the model previously scored only the parts.
    if reported >= THRESHOLDS["SEVERITY_HIGH"] and max_symptom_weight >= 4:
        score += THRESHOLDS["SEVERITY_DANGER_POINTS"]
        factors.append("Severe presentation of a high-risk symptom")

    vulnerable_age = years <= THRESHOLDS["AGE_CHILD"] or years >= THRESHOLDS["AGE_RISK"]
    if vulnerable_age and days >= THRESHOLDS["DURATION_RISK_DAYS"]:
        score += THRESHOLDS["PROLONGED_VULNERABLE_POINTS"]
        factors.append("Prolonged illness at a vulnerable age")

    # Chronic conditions come last so that their factors read after the acute
    # ones -- "high symptom severity" then "asthma with breathlessness".
    condition_score, condition_factors = comorbidity.assess(
        conditions, confirmed_symptoms
    )
    score += condition_score
    factors.extend(condition_factors)

    if not factors:
        factors.append("General assessment")

    if score >= 61:
        level = "High"
    elif score >= 31:
        level = "Moderate"
    else:
        level = "Low"
    return RiskAssessment(level=level, score=score, factors=factors)


# ---------------------------------------------------------------------------
# Intake questions
# ---------------------------------------------------------------------------
# Plausibility bounds and the wording used when a value falls outside them.
INTAKE_LIMITS = {
    "age": (
        THRESHOLDS["AGE_MIN"], THRESHOLDS["AGE_MAX"],
        "Please enter an age between {low} and {high}.",
    ),
    "duration_days": (
        THRESHOLDS["DURATION_MIN_DAYS"], THRESHOLDS["DURATION_MAX_DAYS"],
        "Please enter how many days, between {low} and {high}.",
    ),
    "severity": (
        THRESHOLDS["SEVERITY_MIN"], THRESHOLDS["SEVERITY_MAX"],
        "Please rate severity from {low} to {high}.",
    ),
}


def validate_intake(attribute: str, value: Optional[int]) -> Optional[str]:
    """Return a correction message for an implausible intake value, else None.

    Age, duration and severity each shift the risk score on their own, so a
    fat-fingered 999 quietly changes the advice a user receives. The app
    validates before sending; this is the server refusing to take the number
    on trust.
    """
    limits = INTAKE_LIMITS.get(attribute)
    if limits is None or value is None:
        return None
    low, high, template = limits
    if value < low or value > high:
        return template.format(low=low, high=high)
    return None


def sanitize_intake(state: "TriageState") -> List[str]:
    """Drop implausible intake values from the state; return what was dropped.

    Used for values arriving as message metadata, where there is no question
    to re-ask -- discarding is better than letting 999 drive the assessment.
    """
    dropped = []
    for attribute in INTAKE_LIMITS:
        value = getattr(state, attribute, None)
        if validate_intake(attribute, value) is not None:
            logger.warning(
                "Discarding implausible %s from metadata: %r", attribute, value
            )
            setattr(state, attribute, None)
            dropped.append(attribute)
    return dropped


_INTAKE = (
    (STAGE_AGE, "age", "Before we proceed, could you please tell me your age?",
     "What is your age?"),
    (STAGE_DURATION, "duration_days",
     "How many days have you been experiencing these symptoms?",
     "How many days have you had these symptoms?"),
    (STAGE_SEVERITY, "severity",
     "On a scale of 1-10, how severe are your symptoms overall?",
     "Severity (1-10)?"),
)


def _next_intake(state: TriageState) -> Optional[BotMessage]:
    for stage, attribute, text, prompt in _INTAKE:
        if getattr(state, attribute) is None:
            state.stage = stage
            return BotMessage(
                text=text,
                payload={"type": "question", "question": prompt,
                         "question_text": prompt, "input_type": "number"},
            )
    return None


# ---------------------------------------------------------------------------
# Engine
# ---------------------------------------------------------------------------
def start(kb: KnowledgeBase, text: str, state: Optional[TriageState] = None) -> Outcome:
    """Begin or extend an assessment from free-text symptoms."""
    state = state or TriageState()

    found = extract_symptoms(text, kb.vocabulary)
    if not found:
        return Outcome(
            messages=[BotMessage(
                text="I couldn't quite understand your symptoms. Could you "
                     "describe them differently? (e.g. 'I have a high fever "
                     "and headache')",
                payload={"type": "clarification", "input_type": "text"},
            )],
            state=state,
        )

    for symptom in found:
        state.confirm(symptom)
    state.confirmed = dedupe(state.confirmed)
    state.pending = None
    return advance(kb, state)


def advance(kb: KnowledgeBase, state: TriageState) -> Outcome:
    """Decide the next move: ask for intake data, ask a question, or conclude."""
    intake = _next_intake(state)
    if intake is not None:
        return Outcome(messages=[intake], state=state)
    state.stage = None

    scores = scoring.apply_guards(
        scoring.rank(kb, state.confirmed, state.denied), state.confirmed
    )

    reached_cap = state.question_count >= MAX_QUESTIONS
    decisive = (
        scores
        and scores[0].probability >= THRESHOLDS["CONFIDENCE_DECISIVE"]
        and len(state.confirmed) >= MIN_SYMPTOMS_TO_CONCLUDE
        and state.evidence_count >= MIN_SYMPTOMS_TO_CONCLUDE
    )
    if reached_cap or decisive:
        return conclude(kb, state, scores)

    candidate = scoring.best_question(kb, scores, state.asked)
    if candidate is None:
        return conclude(kb, state, scores)

    # Adaptive stopping. MAX_QUESTIONS was a flat cap, so an obvious
    # presentation and an ambiguous one both cost the user five questions.
    # Once no remaining question has a realistic chance of changing which
    # condition leads, further questions are theatre -- they make the app look
    # thorough while telling it nothing, and every one of them is a chance for
    # the user to abandon the assessment half-finished.
    exhausted = (
        candidate.value < scoring.MIN_QUESTION_VALUE
        and state.question_count >= MIN_QUESTIONS
        and state.evidence_count >= MIN_SYMPTOMS_TO_CONCLUDE
    )
    if exhausted:
        logger.debug(
            "Stopping early after %d question(s): best remaining question "
            "(%s) scores %.3f", state.question_count, candidate.symptom,
            candidate.value,
        )
        return conclude(kb, state, scores)

    next_symptom = candidate.symptom
    state.pending = next_symptom
    state.mark_asked(next_symptom)
    state.question_count += 1

    text = followup_question(next_symptom)
    return Outcome(
        messages=[BotMessage(
            text=text,
            payload={
                "type": "question",
                "question": text,
                "question_text": text,
                "reason": question_reason(next_symptom),
                "question_number": state.question_count,
                "estimated_total": MAX_QUESTIONS,
                "input_type": "yes_no",
            },
        )],
        state=state,
    )


def _no_match_outcome(state: TriageState, scores: List[scoring.DiseaseScore]) -> Outcome:
    alternatives = [
        {"name": s.name, "confidence": s.confidence, "band": s.band}
        for s in scores[1:3]
    ]
    payload = {
        "type": "result",
        "top_condition": None,
        "confidence": int(round(scores[0].probability * 100)) if scores else 0,
        "confidence_band": scoring.BAND_UNCLEAR,
        "confidence_label": scoring.band_label(scoring.BAND_UNCLEAR),
        "risk": "low",
        "matched_symptoms": [display(s) for s in state.confirmed],
        "alternatives": alternatives,
        "advice": ["Please provide more details or consult a doctor."],
        "care_plan": care_plan.DEFAULT_CARE_PLAN,
        "disclaimer": DISCLAIMER.strip(),
    }
    payload.update(disposition_payload(DISPOSITION_SOON))
    payload["recommended_action"] = (
        "Consult a healthcare provider for further evaluation."
    )
    return Outcome(
        messages=[BotMessage(
            text="Your symptoms don't clearly match a known condition.\n"
                 "Please describe more symptoms or consult a healthcare "
                 "provider." + DISCLAIMER,
            payload=payload,
        )],
        state=reset_assessment(state),
        finished=True,
    )


def conclude(
    kb: KnowledgeBase,
    state: TriageState,
    scores: Optional[List[scoring.DiseaseScore]] = None,
) -> Outcome:
    """Produce the final assessment."""
    if scores is None:
        scores = scoring.apply_guards(
            scoring.rank(kb, state.confirmed, state.denied), state.confirmed
        )

    if not scores or scores[0].probability < THRESHOLDS["CONFIDENCE_MINIMUM"]:
        return _no_match_outcome(state, scores)

    top = scores[0]
    band = scoring.resolve_band(top, state.evidence_count)
    risk = calculate_risk(
        state.age, state.duration_days, state.severity,
        kb.max_severity(state.confirmed),
        conditions=state.conditions,
        confirmed_symptoms=state.confirmed,
    )
    advice = kb.advice_for(top.disease)
    specialist = get_specialist(top.disease)
    plan = care_plan.get_care_plan(top.disease)

    # A confident answer needs no hedging; a weak one deserves company.
    if band == scoring.BAND_LIKELY:
        alternatives = []
    elif band == scoring.BAND_POSSIBLE:
        alternatives = scores[1:2]
    else:
        alternatives = scores[1:3]
    alternative_payload = [
        {"name": s.name, "confidence": s.confidence, "band": s.band}
        for s in alternatives
    ]

    ranked_symptoms = sorted(
        state.confirmed, key=lambda s: (-kb.severity_of(s), s)
    )

    payload = {
        "type": "result",
        "top_condition": top.name,
        "condition": top.name,  # backwards compat with older app builds
        "is_unspecified": top.is_other,
        "confidence": top.confidence,
        "confidence_band": band,
        "confidence_label": scoring.band_label(band),
        "risk": risk.level.lower(),
        "risk_score": risk.score,
        "risk_factors": risk.factors,
        "recommended_action": risk.recommended_action,
        "matched_symptoms": [display(s) for s in ranked_symptoms],
        "ruled_out_symptoms": [display(s) for s in state.denied],
        "unknown_symptoms": [display(s) for s in state.unknown],
        "alternatives": alternative_payload,
        "advice": advice,
        "care_plan": plan,
        "specialist": specialist,
        "questions_asked": state.question_count,
        "evidence_count": state.evidence_count,
        "disclaimer": DISCLAIMER.strip(),
    }
    payload.update(disposition_payload(risk.disposition))
    payload["changes_answer"] = _counterfactual(kb, state, scores)

    return Outcome(
        messages=[
            BotMessage(text=_render_result(top, band, risk, alternative_payload,
                                           plan, ranked_symptoms,
                                           payload["changes_answer"]),
                       payload=payload),
            BotMessage(text="Was this helpful? (yes/no)"),
        ],
        state=reset_assessment(state, stage=STAGE_FEEDBACK),
        finished=True,
    )


def _counterfactual(
    kb: KnowledgeBase, state: TriageState, scores: List[scoring.DiseaseScore]
) -> Optional[Dict[str, str]]:
    """The one unreported symptom that would most change this conclusion.

    Shown to the user as "what would change this answer". An assessment built
    from five yes/no questions and a 41-condition knowledge base is going to be
    wrong sometimes, and the useful response to that is not a longer
    disclaimer but telling people exactly where the answer is load-bearing --
    so someone who *does* have the symptom knows to go back, and someone who
    does not gains a reason to trust the rest.
    """
    found = scoring.decisive_symptom(kb, scores, state.asked)
    if found is None:
        return None
    symptom, condition = found
    return {
        "symptom": display(symptom),
        "condition": scoring.OTHER_DISPLAY if condition == scoring.OTHER_DISEASE
        else display(condition),
    }


def _render_result(
    top, band, risk, alternatives, plan, ranked_symptoms, changes_answer=None
) -> str:
    entry = DISPOSITIONS[risk.disposition]
    lines = [
        # The action first, the label for it second, the condition third.
        # Someone who reads one line of this should still know what to do.
        "**{}** — {}".format(entry["label"], entry["timeframe"]),
        "{}\n".format(entry["detail"]),
    ]
    if top.is_other:
        lines.append(
            "Your symptoms do not point clearly to a single condition in our "
            "knowledge base. That is common, and often means something "
            "self-limiting.\n"
        )
    else:
        lines.append(
            "Possible explanation ({}): **{}**\n".format(
                scoring.band_label(band).lower(), top.name
            )
        )
    lines.extend([
        "Risk Level: {} (Score: {})\n".format(risk.level, risk.score),
        "Risk Factors Considered:",
    ])
    lines.extend("✓ {}".format(factor) for factor in risk.factors)
    lines.append("")

    if alternatives:
        lines.append("Other Potential Matches:")
        lines.extend(
            "{}. {}".format(i, alt["name"]) for i, alt in enumerate(alternatives, start=2)
        )
        lines.append("")

    lines.append("What you can do:")
    if plan.get("goal"):
        lines.append("_{}_".format(plan["goal"]))
    lines.extend(care_plan.flatten(plan))

    if changes_answer:
        lines.append(
            "\nWhat would change this: if you also had **{}**, this would "
            "point to {} instead.".format(
                changes_answer["symptom"], changes_answer["condition"]
            )
        )

    lines.append(DISCLAIMER)

    lines.append(
        "\n---\n**Session Summary:**\n"
        "• **Symptoms:** {}\n"
        "• **Suggested next step:** {}\n"
        "• **Possible explanation:** {}\n"
        "• **Risk Level:** {}\n---".format(
            ", ".join(display(s) for s in ranked_symptoms) or "None recorded",
            DISPOSITIONS[risk.disposition]["label"],
            top.name,
            risk.level,
        )
    )
    return "\n".join(lines)


def reset_assessment(state: TriageState, stage: Optional[str] = None) -> TriageState:
    """Clear per-assessment evidence, keeping the conversation alive."""
    return TriageState(stage=stage)


def emergency_outcome(reason: Optional[str] = None) -> Outcome:
    """The response to a detected red flag: stop triage, escalate."""
    payload = {
        "type": "emergency",
        "emergency": True,
        "category": emergency.CATEGORY_EMERGENCY,
        "reason": display(reason) if reason else None,
    }
    payload.update(disposition_payload(DISPOSITION_EMERGENCY))
    return Outcome(
        messages=[BotMessage(text=emergency.EMERGENCY_MESSAGE, payload=payload)],
        state=TriageState(),
        finished=True,
    )


def crisis_outcome(reason: Optional[str] = None) -> Outcome:
    """The response to disclosed suicidal ideation or self-harm.

    A separate outcome from emergency_outcome, and the separation is the
    point. Both used to produce the same message: "call your local emergency
    number or go to the nearest emergency department". For someone who has
    just typed that they want to die, that is a bad answer -- it is the
    hardest possible first step, it reads as being handed off, and it is not
    what crisis services exist for.

    The payload carries `category: crisis` so the app can show crisis-line
    numbers for the user's country in place of the ambulance button, the same
    way emergency numbers are already resolved per locale. The text here never
    interrogates, never minimises, and does not ask the user to answer
    anything -- triage is over.
    """
    payload = {
        "type": "emergency",  # older builds route on this and must still escalate
        "emergency": True,
        "category": emergency.CATEGORY_CRISIS,
        "crisis": True,
        "reason": None,  # never echo the phrase that matched back at the user
    }
    payload.update(disposition_payload(DISPOSITION_EMERGENCY))
    payload["disposition_label"] = "Talk to someone now"
    payload["disposition_detail"] = (
        "Crisis lines are free, confidential and available right now."
    )
    return Outcome(
        messages=[BotMessage(text=emergency.CRISIS_MESSAGE, payload=payload)],
        state=TriageState(),
        finished=True,
    )


def red_flag_outcome(flag: emergency.RedFlag) -> Outcome:
    """Dispatch a detected red flag to the response its category calls for."""
    if flag.is_crisis:
        return crisis_outcome(flag.phrase)
    return emergency_outcome(flag.phrase)


def classify_red_flag(
    text: Optional[str], state: Optional[TriageState] = None
) -> Optional[emergency.RedFlag]:
    """Red flag in the latest message or in what the user has confirmed."""
    confirmed = state.confirmed if state else ()
    return emergency.classify(text=text, symptoms=confirmed)


def check_emergency(text: Optional[str], state: Optional[TriageState] = None) -> Optional[str]:
    """Phrase-only form of classify_red_flag, for callers that want a string."""
    flag = classify_red_flag(text, state)
    return flag.phrase if flag else None
