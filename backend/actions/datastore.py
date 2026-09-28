"""Loading and validation of the CSV knowledge base.

Everything the triage engine knows about diseases lives in four CSVs. This
module reads them exactly once, normalises every key on the way in, and fails
loudly if a file is missing or unusable -- previously each loader swallowed all
exceptions and the bot degraded silently into "I could not identify a
condition" with nothing in the logs.
"""
import csv
import logging
import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set

from . import prevalence
from .normalize import NON_SYMPTOMS, normalize_disease, normalize_symptom

logger = logging.getLogger(__name__)

_BASE_PATH = os.path.dirname(__file__)
_DATASETS = os.path.join(_BASE_PATH, "..", "datasets")

DATASET_PATH = os.path.join(_DATASETS, "dataset.csv")
DESCRIPTION_PATH = os.path.join(_DATASETS, "symptom_Description.csv")
PRECAUTION_PATH = os.path.join(_DATASETS, "symptom_precaution.csv")
SEVERITY_PATH = os.path.join(_DATASETS, "Symptom-severity.csv")

# Advice we refuse to relay from the dataset: prescriptive treatment, drug
# names, or remedies that are unsafe as blanket guidance to an unknown user.
_UNSAFE_ADVICE_TERMS = (
    "papaya", "radioactive", "witch hazel", "medication", "antibiotic",
    "antiboitic", "therapy", "asprin", "aspirin", "vaccine", "surgery",
)

_ADVICE_SPELLING_FIXES = {
    "vegitables": "vegetables",
    "antiboitic": "antibiotic",
}

# Appended to every condition's advice, and used alone when nothing in the
# dataset survives filtering.
GENERAL_ADVICE = [
    "Stay hydrated and get adequate rest",
    "Maintain good hygiene",
    "Seek medical attention if symptoms worsen",
]


class DatasetError(RuntimeError):
    """Raised when the knowledge base cannot be loaded or is unusable."""


@dataclass
class KnowledgeBase:
    """The loaded CSVs, normalised and indexed for the triage engine."""

    # disease -> every symptom ever recorded for it
    disease_symptoms: Dict[str, Set[str]] = field(default_factory=dict)
    # disease -> symptom -> number of DISTINCT presentations containing it
    symptom_counts: Dict[str, Dict[str, int]] = field(default_factory=dict)
    # disease -> number of distinct presentations (see _load_dataset)
    disease_rows: Dict[str, int] = field(default_factory=dict)
    # disease -> number of rows in the CSV, distinct or not. Reporting only;
    # nothing scores on it, because the duplicates are not independent cases.
    case_rows: Dict[str, int] = field(default_factory=dict)
    # symptom -> fraction of all distinct presentations that mention it.
    # Used as P(symptom | unspecified illness) by the ranker's escape hatch.
    symptom_base_rate: Dict[str, float] = field(default_factory=dict)
    # symptom -> severity weight (1-5); drives risk scoring only
    severity: Dict[str, int] = field(default_factory=dict)
    descriptions: Dict[str, str] = field(default_factory=dict)
    precautions: Dict[str, List[str]] = field(default_factory=dict)
    # every symptom the engine is willing to recognise
    vocabulary: Set[str] = field(default_factory=set)

    def severity_of(self, symptom: str) -> int:
        return self.severity.get(normalize_symptom(symptom), 1)

    def max_severity(self, symptoms: List[str]) -> int:
        return max([self.severity_of(s) for s in symptoms] + [1])

    def base_rate_of(self, symptom: str) -> float:
        """How common a symptom is across the whole knowledge base."""
        return self.symptom_base_rate.get(normalize_symptom(symptom), 0.0)

    def advice_for(self, disease: str) -> List[str]:
        return self.precautions.get(normalize_disease(disease), list(GENERAL_ADVICE))

    def description_of(self, disease: str) -> Optional[str]:
        return self.descriptions.get(normalize_disease(disease))


def _read_csv(path: str, label: str) -> List[List[str]]:
    try:
        with open(path, encoding="utf-8") as handle:
            return [row for row in csv.reader(handle) if row and any(c.strip() for c in row)]
    except FileNotFoundError as exc:
        raise DatasetError("{} not found at {}".format(label, path)) from exc
    except (OSError, UnicodeDecodeError, csv.Error) as exc:
        raise DatasetError("{} at {} could not be read: {}".format(label, path, exc)) from exc


def _load_severity(kb: "KnowledgeBase") -> None:
    for row in _read_csv(SEVERITY_PATH, "Symptom-severity.csv")[1:]:
        symptom = normalize_symptom(row[0])
        if not symptom or symptom in NON_SYMPTOMS:
            continue
        try:
            kb.severity[symptom] = int(row[1])
        except (IndexError, ValueError):
            logger.warning("Severity row for %r has no usable weight; defaulting to 1", symptom)
            kb.severity[symptom] = 1


def _load_dataset(kb: "KnowledgeBase") -> None:
    """Index dataset.csv by DISTINCT presentation, not by row.

    The file carries 120 rows for each of its 41 conditions, and the shape of
    that is easy to misread: they are not 120 observed cases. Collapsed on
    their symptom set, `Fungal infection` has five distinct rows and the other
    115 are permutations and leave-one-out variants of those five. Counting
    rows therefore measured how the file was padded, not how often a symptom
    accompanies a condition, while making the sample look 24x larger than it
    is -- which drove Laplace smoothing to near-nothing and the posterior to
    unearned confidence.

    Counting distinct presentations is the honest reading of the same file: a
    symptom present in four of five recorded patterns scores 4/5, and the
    smoothing prior stays meaningful against a sample that small. It also
    keeps the numbers reproducible if the padding is ever regenerated.
    """
    seen: Dict[str, Set[frozenset]] = {}
    for row in _read_csv(DATASET_PATH, "dataset.csv")[1:]:
        disease = normalize_disease(row[0])
        if not disease:
            continue
        symptoms = {normalize_symptom(s) for s in row[1:] if s.strip()}
        symptoms.discard("")

        kb.case_rows[disease] = kb.case_rows.get(disease, 0) + 1
        kb.disease_symptoms.setdefault(disease, set()).update(symptoms)
        kb.vocabulary.update(symptoms)

        presentation = frozenset(symptoms)
        recorded = seen.setdefault(disease, set())
        if presentation in recorded:
            continue
        recorded.add(presentation)

        kb.disease_rows[disease] = kb.disease_rows.get(disease, 0) + 1
        counts = kb.symptom_counts.setdefault(disease, {})
        for symptom in symptoms:
            counts[symptom] = counts.get(symptom, 0) + 1


def _index_base_rates(kb: "KnowledgeBase") -> None:
    """How often each symptom appears across every condition in the base.

    This is the ranker's stand-in for P(symptom | something we do not model).
    A symptom that shows up in a quarter of all recorded presentations says
    little about which condition is present; one that shows up in two says a
    great deal. See scoring.OTHER_DISEASE.
    """
    total = sum(kb.disease_rows.values())
    if not total:
        return
    tally: Dict[str, int] = {}
    for counts in kb.symptom_counts.values():
        for symptom, count in counts.items():
            tally[symptom] = tally.get(symptom, 0) + count
    kb.symptom_base_rate = {
        symptom: count / total for symptom, count in tally.items()
    }


def _load_descriptions(kb: "KnowledgeBase") -> None:
    for row in _read_csv(DESCRIPTION_PATH, "symptom_Description.csv")[1:]:
        if len(row) >= 2:
            kb.descriptions[normalize_disease(row[0])] = row[1].strip()


def _clean_advice(raw: List[str]) -> List[str]:
    """Drop prescriptive or unsafe advice, repair spelling, dedupe."""
    cleaned: List[str] = []
    for item in raw:
        text = item.strip()
        if not text:
            continue
        if any(term in text.lower() for term in _UNSAFE_ADVICE_TERMS):
            continue
        for wrong, right in _ADVICE_SPELLING_FIXES.items():
            text = text.replace(wrong, right).replace(wrong.capitalize(), right.capitalize())
        text = text[0].upper() + text[1:]
        if text not in cleaned:
            cleaned.append(text)
    return cleaned


def _load_precautions(kb: "KnowledgeBase") -> None:
    for row in _read_csv(PRECAUTION_PATH, "symptom_precaution.csv")[1:]:
        disease = normalize_disease(row[0])
        if not disease:
            continue
        # Condition-specific advice first, then the baseline that always applies.
        advice = _clean_advice(list(row[1:]))
        for general in GENERAL_ADVICE:
            if general not in advice:
                advice.append(general)
        kb.precautions[disease] = advice


def _validate(kb: "KnowledgeBase") -> None:
    """Log every inconsistency; raise only on damage the engine cannot survive."""
    if not kb.disease_symptoms:
        raise DatasetError("dataset.csv produced no diseases -- the triage engine cannot run")
    if not kb.severity:
        raise DatasetError("Symptom-severity.csv produced no weights -- risk scoring cannot run")

    unweighted = sorted(kb.vocabulary - set(kb.severity))
    if unweighted:
        logger.warning(
            "%d symptom(s) in dataset.csv have no severity weight (defaulting to 1): %s",
            len(unweighted), ", ".join(unweighted),
        )
    unused = sorted(set(kb.severity) - kb.vocabulary)
    if unused:
        logger.info(
            "%d symptom(s) in Symptom-severity.csv never appear in dataset.csv: %s",
            len(unused), ", ".join(unused),
        )
    missing_advice = sorted(set(kb.disease_symptoms) - set(kb.precautions))
    if missing_advice:
        logger.warning(
            "%d disease(s) have no precaution row; general advice will be used: %s",
            len(missing_advice), ", ".join(missing_advice),
        )
    untiered = prevalence.unmapped(kb.disease_symptoms)
    if untiered:
        logger.warning(
            "%d disease(s) have no prevalence tier and default to %r: %s",
            len(untiered), prevalence.DEFAULT_TIER, ", ".join(untiered),
        )
    logger.info(
        "Knowledge base loaded: %d diseases, %d symptoms, %d distinct "
        "presentations (from %d CSV rows), region %r",
        len(kb.disease_symptoms), len(kb.vocabulary),
        sum(kb.disease_rows.values()), sum(kb.case_rows.values()),
        prevalence.configured_region(),
    )


_CACHE = None  # type: Optional[KnowledgeBase]


def load(force: bool = False) -> KnowledgeBase:
    """Return the shared knowledge base, loading it on first use."""
    global _CACHE
    if _CACHE is not None and not force:
        return _CACHE
    kb = KnowledgeBase()
    _load_severity(kb)
    _load_dataset(kb)
    _index_base_rates(kb)
    _load_descriptions(kb)
    _load_precautions(kb)
    _validate(kb)
    _CACHE = kb
    return kb
