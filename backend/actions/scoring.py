"""Probabilistic disease ranking.

dataset.csv records 41 conditions as a set of distinct symptom patterns each
(see datastore._load_dataset for why "distinct" is doing real work there), so
how often a symptom accompanies a condition is measurable rather than
guessable. That makes a naive Bayes model the natural fit, and it fixed three
problems the original ratio heuristic had:

* matched_weight / total_weight punished diseases for having long symptom
  lists, so 2-of-3 symptoms outranked 8-of-15 despite being weaker evidence;
* answering "no" narrowed the candidate list but never touched the final
  ranking, because scoring only ever looked at confirmed symptoms;
* the resulting percentage was shown to users as a "confidence" while being an
  overlap ratio, which is not a probability of anything.

Three later corrections, each addressing a way the model was confidently wrong
rather than merely imprecise:

* **A prior.** Ranking assumed every condition equally likely before any
  symptom was heard, so AIDS competed with the common cold on fit alone.
  prevalence.py supplies a coarse, region-aware prior instead.
* **An escape hatch.** The model had 41 answers and no way to say "none of
  these". Most people who open a symptom checker have something self-limiting
  and unnamed, so OTHER_DISEASE competes as a real candidate rather than the
  ranker being forced to nominate a condition it does not believe in.
* **Calibration.** Naive Bayes assumes symptoms are independent given the
  disease. Real symptoms cluster hard -- fever, chills and sweating are close
  to one observation, not three -- so evidence was counted several times over
  and the softmax saturated. _TEMPERATURE discounts repeated evidence.

Severity weights play no part here. They describe how dangerous a symptom is,
which drives risk assessment (see triage.calculate_risk) and which question to
ask next -- not how strongly a symptom implies one disease over another.
"""
import math
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

from . import prevalence
from .normalize import display, normalize_symptom

# Laplace smoothing. Without it a single symptom never recorded for a disease
# drives its probability to zero and no later evidence can recover it.
_ALPHA = 1.0

# Discounts correlated evidence. Every confirmed or denied symptom has its
# log-likelihood divided by this, so ten clustered symptoms argue roughly like
# six independent ones. It is a blunt instrument -- the principled fix is to
# model the correlations -- but it is honest about the direction of the error,
# and it is the difference between the UI showing 97% and showing 71% for
# evidence that deserves neither certainty nor dismissal. The prior is applied
# undiscounted: it is not evidence and is not double counted.
_TEMPERATURE = 1.35

# How much a "no" counts relative to a "yes". Denials are real evidence and
# the engine was right to start using them, but weighting them equally was
# wrong for a structural reason: dataset.csv records the *union* of symptoms
# ever seen with a condition, and no real patient has all of them. Absence is
# therefore the normal case, not a contradiction.
#
# At equal weight the arithmetic turned pathological in exactly the situation
# the engine is built for. Question selection deliberately asks about symptoms
# that distinguish the leading candidates, so most answers are "no"; each one
# then hammered the very condition it was chosen to test, while barely
# touching "unspecified illness", whose base rates are low for everything. The
# evaluation suite caught the result: eight textbook presentations -- a plain
# UTI among them -- interrogated their way from a correct leading answer to
# "no single condition stands out".
_DENIAL_WEIGHT = 0.45

# The ranker's "none of the above". Its likelihood for any symptom is that
# symptom's base rate across the knowledge base, so it wins when the reported
# symptoms are common and unrevealing (fever, fatigue, headache) and loses to
# any condition the evidence actually singles out.
OTHER_DISEASE = "unspecified illness"
OTHER_DISPLAY = "No single condition stands out"

# Share of prior probability held by OTHER_DISEASE before any evidence. A
# knowledge base of 41 conditions does not cover the space of reasons a person
# feels unwell, and pretending otherwise is what made the old model name
# something every single time. Conservative: the true share is higher.
OTHER_PRIOR_SHARE = 0.30

# P(symptom | unspecified illness) is clamped into this range. The floor stops
# a symptom absent from the base rates handing OTHER a probability of zero; the
# ceiling stops a very common symptom making OTHER unbeatable.
_OTHER_RATE_FLOOR = 0.02
_OTHER_RATE_CEILING = 0.45

# Conditions serious enough that we require corroborating evidence before
# naming them, regardless of what the arithmetic says.
GUARDED_DISEASES = ("heart attack", "paralysis (brain hemorrhage)")
GUARDED_MIN_SYMPTOMS = 4

# Probability bands. Users see the band; the raw number stays in the payload
# for the UI meter, but a percentage from a 41-condition teaching dataset
# should not be presented as clinical precision.
BAND_LIKELY = "likely"
BAND_POSSIBLE = "possible"
BAND_UNCLEAR = "unclear"

_BAND_LABELS = {
    BAND_LIKELY: "Likely match",
    BAND_POSSIBLE: "Possible match",
    BAND_UNCLEAR: "Unclear match",
}

_BAND_THRESHOLDS = ((0.55, BAND_LIKELY), (0.22, BAND_POSSIBLE))

# Below this many answered questions we never claim more than "possible",
# however lopsided the posterior looks.
_MIN_EVIDENCE_FOR_LIKELY = 3

# A question is worth asking if there is at least this much chance its answer
# changes which condition is leading. Below it we are asking to look thorough,
# which costs the user time and costs us their patience.
MIN_QUESTION_VALUE = 0.04

# Added to the value of a question about a symptom the severity table rates 4
# or higher. Asking "any chest pain?" has worth beyond discrimination: a yes
# routes to the emergency path regardless of what it does to the ranking.
_SAFETY_BONUS = 0.18
_SAFETY_SEVERITY = 4


@dataclass
class DiseaseScore:
    disease: str
    probability: float
    matched: List[str]
    missing: List[str]

    @property
    def confidence(self) -> int:
        """Posterior as a whole percentage, for display meters."""
        return int(round(self.probability * 100))

    @property
    def band(self) -> str:
        for threshold, band in _BAND_THRESHOLDS:
            if self.probability >= threshold:
                return band
        return BAND_UNCLEAR

    @property
    def is_other(self) -> bool:
        return self.disease == OTHER_DISEASE

    @property
    def name(self) -> str:
        return OTHER_DISPLAY if self.is_other else display(self.disease)


@dataclass
class QuestionCandidate:
    """One symptom we could ask about, and what asking would be worth."""

    symptom: str
    # Probability that the answer changes which condition leads the ranking.
    value: float
    # P(yes) under the current posterior. 0.5 is maximally uninformative to
    # predict, which is what makes it informative to ask.
    split: float
    severity: int

    @property
    def is_safety_question(self) -> bool:
        return self.severity >= _SAFETY_SEVERITY


def band_label(band: str) -> str:
    return _BAND_LABELS.get(band, _BAND_LABELS[BAND_UNCLEAR])


def symptom_probability(kb, disease: str, symptom: str) -> float:
    """P(symptom | disease), Laplace-smoothed.

    For OTHER_DISEASE there is nothing to smooth: the answer is how common the
    symptom is generally, which is what "some other illness" predicts.
    """
    if disease == OTHER_DISEASE:
        rate = kb.base_rate_of(symptom)
        return min(max(rate, _OTHER_RATE_FLOOR), _OTHER_RATE_CEILING)
    rows = kb.disease_rows.get(disease, 0)
    count = kb.symptom_counts.get(disease, {}).get(symptom, 0)
    return (count + _ALPHA) / (rows + 2 * _ALPHA)


def _log_likelihood(
    kb, disease: str, confirmed: Sequence[str], denied: Sequence[str]
) -> float:
    """log P(evidence | disease), discounted for correlated evidence.

    Symptoms the user was unsure about appear in neither list and so contribute
    nothing -- they are genuinely missing data, not evidence of absence.
    """
    total = 0.0
    for symptom in confirmed:
        total += math.log(symptom_probability(kb, disease, symptom))
    for symptom in denied:
        total += _DENIAL_WEIGHT * math.log(
            1.0 - symptom_probability(kb, disease, symptom)
        )
    return total / _TEMPERATURE


def priors(
    kb, candidates: Optional[Iterable[str]] = None, region: Optional[str] = None
) -> Dict[str, float]:
    """Prior over the candidate pool, including OTHER_DISEASE.

    Diseases share (1 - OTHER_PRIOR_SHARE) in proportion to their prevalence
    tier; OTHER_DISEASE takes the rest.
    """
    pool = list(kb.disease_symptoms) if candidates is None else list(candidates)
    pool = [d for d in pool if d != OTHER_DISEASE]
    weighted = prevalence.weights(pool, region)
    prior = {
        disease: weight * (1.0 - OTHER_PRIOR_SHARE)
        for disease, weight in weighted.items()
    }
    prior[OTHER_DISEASE] = OTHER_PRIOR_SHARE if weighted else 1.0
    return prior


def rank(
    kb,
    confirmed: Iterable[str],
    denied: Iterable[str] = (),
    candidates: Optional[Iterable[str]] = None,
    region: Optional[str] = None,
    include_other: bool = True,
) -> List[DiseaseScore]:
    """Rank conditions by posterior probability given the evidence so far.

    `candidates` restricts scoring to a shortlist; pass None to score every
    condition. `include_other` adds the "none of these" candidate, which is on
    by default because leaving it out is what forces a diagnosis. Ranking is
    deterministic -- ties break on disease name.
    """
    confirmed_keys = [normalize_symptom(s) for s in confirmed]
    confirmed_keys = [s for s in confirmed_keys if s]
    denied_keys = [normalize_symptom(s) for s in denied]
    denied_keys = [s for s in denied_keys if s and s not in confirmed_keys]

    pool = sorted(kb.disease_symptoms) if candidates is None else sorted(set(candidates))
    pool = [d for d in pool if d in kb.disease_symptoms]
    if not pool or not (confirmed_keys or denied_keys):
        return []

    prior = priors(kb, pool, region)
    if include_other:
        pool = pool + [OTHER_DISEASE]

    log_scores = {}
    for disease in pool:
        weight = prior.get(disease, 0.0)
        if weight <= 0.0:
            continue
        log_scores[disease] = (
            math.log(weight)
            + _log_likelihood(kb, disease, confirmed_keys, denied_keys)
        )
    if not log_scores:
        return []

    # Softmax in log space; subtracting the max keeps exp() from underflowing.
    highest = max(log_scores.values())
    weights = {d: math.exp(score - highest) for d, score in log_scores.items()}
    total = sum(weights.values()) or 1.0

    confirmed_set: Set[str] = set(confirmed_keys)
    scores = []
    for disease in log_scores:
        symptoms = kb.disease_symptoms.get(disease, set())
        matched = [s for s in confirmed_keys if s in symptoms]
        missing = sorted(s for s in symptoms if s not in confirmed_set)
        scores.append(
            DiseaseScore(
                disease=disease,
                probability=weights[disease] / total,
                matched=matched,
                missing=missing,
            )
        )
    scores.sort(key=lambda s: (-s.probability, s.disease))
    return scores


def apply_guards(scores: List[DiseaseScore], confirmed: Sequence[str]) -> List[DiseaseScore]:
    """Suppress serious conditions that lack corroborating symptoms."""
    confirmed_count = len(confirmed)
    kept = []
    for score in scores:
        guarded = any(g in score.disease for g in GUARDED_DISEASES)
        if guarded and (len(score.matched) < GUARDED_MIN_SYMPTOMS or confirmed_count < GUARDED_MIN_SYMPTOMS):
            continue
        kept.append(score)
    return kept


def resolve_band(score: DiseaseScore, evidence_count: int) -> str:
    """Band for a score, capped while the evidence base is still thin."""
    band = score.band
    if band == BAND_LIKELY and evidence_count < _MIN_EVIDENCE_FOR_LIKELY:
        return BAND_POSSIBLE
    return band


# ---------------------------------------------------------------------------
# Choosing the next question
# ---------------------------------------------------------------------------
def _candidate_pool(kb, scores: List[DiseaseScore], asked: Iterable[str]) -> Set[str]:
    asked_keys = {normalize_symptom(s) for s in asked}
    pool: Set[str] = set()
    for score in scores:
        pool.update(kb.disease_symptoms.get(score.disease, set()))
    return pool - asked_keys


def _leader(pairs: Sequence[Tuple[str, float]]) -> Optional[str]:
    """Disease with the highest weight; ties break on name, as rank() does."""
    if not pairs:
        return None
    return min(pairs, key=lambda p: (-p[1], p[0]))[0]


def best_question(
    kb,
    scores: List[DiseaseScore],
    asked: Iterable[str],
    limit: int = 40,
) -> Optional[QuestionCandidate]:
    """The most useful symptom to ask about next, or None if none is useful.

    The original version maximised entropy over the label: it asked whichever
    symptom it could least predict the answer to. That is the textbook answer
    to a question we are not asking. What matters is not how surprising the
    answer is but whether it *changes anything* -- a symptom that splits the
    field perfectly while leaving the same condition on top is a question we
    made the user answer for nothing.

    So each candidate is scored by the probability that its answer moves a
    different condition into the lead, computed by actually reweighting the
    posterior both ways. Entropy survives as a tie-break, which is where it
    belongs. Symptoms the severity table rates dangerous get a bonus, because
    a "yes" to chest pain is worth having whatever it does to the ranking.
    """
    shortlist = scores[:limit]
    if not shortlist:
        return None
    pool = _candidate_pool(kb, shortlist, asked)
    if not pool:
        return None

    current = [(s.disease, s.probability) for s in shortlist]
    leader = _leader(current)
    total_probability = sum(s.probability for s in shortlist) or 1.0

    best: Optional[QuestionCandidate] = None
    best_key: Optional[Tuple[float, float, int, str]] = None

    for symptom in sorted(pool):
        likelihoods = {
            s.disease: symptom_probability(kb, s.disease, symptom)
            for s in shortlist
        }
        split = sum(
            s.probability * likelihoods[s.disease] for s in shortlist
        ) / total_probability

        if_yes = [(s.disease, s.probability * likelihoods[s.disease]) for s in shortlist]
        if_no = [
            (s.disease, s.probability * (1.0 - likelihoods[s.disease]))
            for s in shortlist
        ]
        flips = 0.0
        if _leader(if_yes) != leader:
            flips += split
        if _leader(if_no) != leader:
            flips += 1.0 - split

        severity = kb.severity_of(symptom)
        value = flips
        if severity >= _SAFETY_SEVERITY:
            value += _SAFETY_BONUS

        key = (-value, abs(split - 0.5), -severity, symptom)
        if best_key is None or key < best_key:
            best_key = key
            best = QuestionCandidate(
                symptom=symptom, value=value, split=split, severity=severity
            )
    return best


def next_question_symptom(
    kb,
    scores: List[DiseaseScore],
    asked: Iterable[str],
    limit: int = 40,
) -> Optional[str]:
    """Name of the next symptom to ask about, or None. See best_question."""
    candidate = best_question(kb, scores, asked, limit)
    return candidate.symptom if candidate else None


def decisive_symptom(
    kb, scores: List[DiseaseScore], asked: Iterable[str], limit: int = 40
) -> Optional[Tuple[str, str]]:
    """The unasked symptom whose presence would most change the conclusion.

    Returned as (symptom, condition it would favour), for the "what would
    change this answer" line on the result screen. Showing the user the single
    fact that would overturn the assessment is the cheapest honesty available
    to a model working from 41 conditions and a handful of questions.
    """
    shortlist = scores[:limit]
    if len(shortlist) < 2:
        return None
    pool = _candidate_pool(kb, shortlist, asked)
    if not pool:
        return None

    leader = shortlist[0].disease
    best: Optional[Tuple[str, str]] = None
    best_margin = 0.0

    for symptom in sorted(pool):
        reweighted = [
            (s.disease, s.probability * symptom_probability(kb, s.disease, symptom))
            for s in shortlist
        ]
        total = sum(weight for _, weight in reweighted) or 1.0
        top = _leader(reweighted)
        if top is None or top == leader:
            continue
        margin = dict(reweighted)[top] / total
        if margin > best_margin:
            best_margin = margin
            best = (symptom, top)
    return best
