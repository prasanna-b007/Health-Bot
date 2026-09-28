"""Chronic conditions as a risk modifier.

The app has always been able to collect a user's ongoing conditions, and until
now it discarded them: `calculate_risk` blended severity, age, symptom danger
and duration, and an asthmatic reporting breathlessness scored exactly the same
as anyone else. This module is the missing input.

It does two things, and deliberately no more:

* **Baseline vulnerability.** A recognised chronic condition raises the floor,
  because a routine infection is not routine in someone immunosuppressed.
* **Interaction.** A condition paired with a symptom that condition makes
  dangerous raises it much further -- asthma with breathlessness is the whole
  reason for this module.

What it does *not* do is diagnose, contraindicate, or reason about drugs.
Allergies and medications are collected by the app for the human clinician who
reads the shared report; inferring interactions from them would be a different
and far more safety-critical piece of software than this is.

Pure functions only -- no Rasa, no tracker -- so the risk behaviour can be
tested directly.
"""
from typing import Dict, Iterable, List, Optional, Set, Tuple

from .config import THRESHOLDS
from .normalize import normalize

# ---------------------------------------------------------------------------
# Recognised conditions
# ---------------------------------------------------------------------------
# Grouped by the kind of vulnerability they create, because the interaction
# rules below are per-group rather than per-condition: COPD and asthma make the
# same symptoms dangerous.
#
# Keys are normalised (lowercase, no punctuation) and matched as substrings of
# the user's text, so "type 2 diabetes" and "diabetes mellitus" both reach
# "diabetes". Order matters only in that the first match wins per entry.
CONDITION_ALIASES: Dict[str, str] = {
    # Respiratory
    "asthma": "respiratory",
    "copd": "respiratory",
    "emphysema": "respiratory",
    "chronic bronchitis": "respiratory",
    "cystic fibrosis": "respiratory",
    "pulmonary fibrosis": "respiratory",
    "sleep apnea": "respiratory",
    "sleep apnoea": "respiratory",
    # Cardiovascular
    "heart disease": "cardiac",
    "heart failure": "cardiac",
    "coronary": "cardiac",
    "angina": "cardiac",
    "arrhythmia": "cardiac",
    "atrial fibrillation": "cardiac",
    "hypertension": "cardiac",
    "high blood pressure": "cardiac",
    "stroke": "cardiac",
    # Metabolic
    "diabetes": "metabolic",
    "diabetic": "metabolic",
    # Immune
    "immunocompromised": "immune",
    "immunosuppressed": "immune",
    "hiv": "immune",
    "aids": "immune",
    "cancer": "immune",
    "chemotherapy": "immune",
    "leukemia": "immune",
    "leukaemia": "immune",
    "lymphoma": "immune",
    "transplant": "immune",
    "lupus": "immune",
    # Renal / hepatic
    "kidney disease": "renal",
    "chronic kidney": "renal",
    "renal failure": "renal",
    "dialysis": "renal",
    "cirrhosis": "renal",
    "liver disease": "renal",
    # Pregnancy is not a disease, but it changes what is safe and what is
    # urgent, which is exactly what this scoring is for.
    "pregnant": "pregnancy",
    "pregnancy": "pregnancy",
}

# Symptoms that are materially more dangerous in the presence of a group.
#
# Every entry must be a canonical dataset symptom name, so that it can actually
# match what lands in TriageState.confirmed. The interaction only fires on a
# *confirmed* symptom -- never on one the user denied or skipped.
GROUP_INTERACTIONS: Dict[str, Set[str]] = {
    "respiratory": {
        "breathlessness",
        "cough",
        "chest pain",
        "phlegm",
        "mucoid sputum",
        "blood in sputum",
        "congestion",
        "high fever",
    },
    "cardiac": {
        "chest pain",
        "breathlessness",
        "fast heart rate",
        "swollen legs",
        "swollen blood vessels",
        "fatigue",
        "dizziness",
    },
    "metabolic": {
        "excessive hunger",
        "increased appetite",
        "polyuria",
        "fatigue",
        "blurred and distorted vision",
        "weight loss",
        "vomiting",
        "high fever",
    },
    "immune": {
        "high fever",
        "mild fever",
        "chills",
        "fatigue",
        "swelled lymph nodes",
        "breathlessness",
    },
    "renal": {
        "swelling of stomach",
        "swollen legs",
        "puffy face and eyes",
        "vomiting",
        "nausea",
        "fatigue",
        "yellowish skin",
    },
    "pregnancy": {
        "abdominal pain",
        "vomiting",
        "high fever",
        "swollen legs",
        "puffy face and eyes",
        "dizziness",
        "headache",
    },
}

# Human-readable group names for the risk factors shown to the user.
GROUP_LABELS: Dict[str, str] = {
    "respiratory": "respiratory condition",
    "cardiac": "heart condition",
    "metabolic": "diabetes",
    "immune": "reduced immunity",
    "renal": "kidney or liver condition",
    "pregnancy": "pregnancy",
}


def classify(condition: Optional[str]) -> Optional[str]:
    """Map free text to a vulnerability group, or None if unrecognised.

    Unrecognised is the common case and is not an error: users type anything,
    and a condition this module does not know about simply does not move the
    score. It is never treated as reassurance.
    """
    text = normalize(condition)
    if not text:
        return None
    for alias, group in CONDITION_ALIASES.items():
        if alias in text:
            return group
    return None


def groups_for(conditions: Optional[Iterable[str]]) -> List[str]:
    """The distinct vulnerability groups present, in a stable order.

    Deduplicated by group: someone listing "asthma" and "COPD" is not twice as
    vulnerable as someone listing one of them, and scoring it that way would
    let a long profile inflate its own risk level.
    """
    seen: List[str] = []
    for condition in conditions or []:
        group = classify(condition)
        if group is not None and group not in seen:
            seen.append(group)
    return seen


def assess(
    conditions: Optional[Iterable[str]],
    confirmed_symptoms: Optional[Iterable[str]] = None,
) -> Tuple[int, List[str]]:
    """Risk points and factor descriptions contributed by chronic conditions.

    Returns (0, []) for an empty or entirely unrecognised list, so a user with
    no profile scores exactly as they did before this module existed.
    """
    groups = groups_for(conditions)
    if not groups:
        return 0, []

    confirmed = {normalize(s) for s in (confirmed_symptoms or []) if s}
    factors: List[str] = []

    baseline = min(
        len(groups) * THRESHOLDS["COMORBIDITY_POINTS"],
        THRESHOLDS["COMORBIDITY_MAX"],
    )
    for group in groups:
        factors.append("Pre-existing {}".format(GROUP_LABELS[group]))

    interaction = 0
    for group in groups:
        overlap = GROUP_INTERACTIONS.get(group, set()) & confirmed
        if not overlap:
            continue
        interaction += THRESHOLDS["COMORBIDITY_INTERACTION_POINTS"]
        # Name the symptom that did it, so the user can see the reasoning
        # rather than a bare "you are high risk".
        factors.append(
            "{} with {}".format(
                GROUP_LABELS[group].capitalize(), sorted(overlap)[0]
            )
        )

    interaction = min(interaction, THRESHOLDS["COMORBIDITY_INTERACTION_MAX"])
    return baseline + interaction, factors
