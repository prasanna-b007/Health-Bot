"""How likely each condition is *before* any symptom is heard.

Ranking used to assume a uniform prior: with 41 conditions in the knowledge
base, AIDS and the common cold started out equally likely, and the only thing
separating them was how well the reported symptoms happened to fit. That is
not how diagnosis works. A symptom set that fits both a common and a rare
condition should land on the common one, and needs much stronger evidence
before it names the rare one.

The weights here are relative, not epidemiological rates. They express how
often a condition turns up among people who would plausibly open a symptom
checker -- which is closer to primary-care presentation frequency than to
population prevalence, and is deliberately coarse. Four tiers is as much
precision as this knowledge base can honestly support; see DATA.md.

Regions matter more than the tiers do. Dengue, typhoid, malaria and
tuberculosis are uncommon presentations in much of Europe and routine ones in
South Asia, so a single global table would be wrong for most users either way.
`weights()` takes a region and applies its overrides on top of the baseline.
"""
import logging
import os
from typing import Dict, Iterable, Optional

from .normalize import normalize_disease

logger = logging.getLogger(__name__)

# Relative weight of each tier. The spread is intentionally wide: the gap
# between "seen every week" and "seen once a career" is orders of magnitude,
# and compressing it would make the prior decorative.
TIER_WEIGHTS = {
    "very_common": 1.0,
    "common": 0.30,
    "uncommon": 0.18,
    "rare": 0.02,
}

DEFAULT_TIER = "uncommon"

# Baseline assignment, written for a general adult population with no regional
# assumption. A condition absent from this table falls to DEFAULT_TIER, which
# errs toward under-naming rather than over-naming it.
BASELINE_TIERS: Dict[str, str] = {
    # Seen constantly in primary care and self-limiting more often than not.
    "common cold": "very_common",
    "allergy": "very_common",
    "gerd": "very_common",
    "migraine": "very_common",
    "fungal infection": "very_common",
    "acne": "very_common",
    "gastroenteritis": "very_common",

    # Common, but a step below: either less frequent or more often managed
    # rather than newly presenting.
    "urinary tract infection": "common",
    "arthritis": "common",
    "osteoarthristis": "common",
    "cervical spondylosis": "common",
    "drug reaction": "common",
    "hypertension": "common",
    "diabetes": "common",
    "hypothyroidism": "common",
    "bronchial asthma": "common",
    "(vertigo) paroymsal positional vertigo": "common",
    "dimorphic hemmorhoids(piles)": "common",
    "varicose veins": "common",
    "impetigo": "common",
    "psoriasis": "common",
    "peptic ulcer diseae": "common",
    "chicken pox": "common",

    # Real but not routine. Several of these are re-tiered by region below.
    "hyperthyroidism": "uncommon",
    "hypoglycemia": "uncommon",
    "pneumonia": "uncommon",
    "jaundice": "uncommon",
    "chronic cholestasis": "uncommon",
    "hepatitis a": "uncommon",
    "hepatitis b": "uncommon",
    "alcoholic hepatitis": "uncommon",
    "dengue": "uncommon",
    "typhoid": "uncommon",
    "malaria": "uncommon",
    "tuberculosis": "uncommon",

    # Rare as a *first* presentation to a symptom checker. Heart attack and
    # brain haemorrhage are not rare events; they are rare things to be typing
    # about, and both are caught by the emergency path long before ranking
    # matters. Keeping them low here stops the ranker naming them speculatively
    # -- scoring.GUARDED_DISEASES is the second belt on the same trousers.
    "heart attack": "rare",
    "paralysis (brain hemorrhage)": "rare",
    "aids": "rare",
    "hepatitis c": "rare",
    "hepatitis d": "rare",
    "hepatitis e": "rare",
}

# Regional overrides, applied on top of BASELINE_TIERS. Only differences are
# listed, so the diff from the baseline is the documentation.
REGION_TIERS: Dict[str, Dict[str, str]] = {
    "global": {},
    "south_asia": {
        "dengue": "common",
        "typhoid": "common",
        "malaria": "common",
        "tuberculosis": "common",
        "hepatitis a": "common",
        "hepatitis e": "uncommon",
        "jaundice": "common",
    },
    "sub_saharan_africa": {
        "malaria": "very_common",
        "tuberculosis": "common",
        "typhoid": "common",
        "aids": "uncommon",
        "hepatitis b": "common",
    },
    "europe": {
        "dengue": "rare",
        "malaria": "rare",
        "typhoid": "rare",
        "tuberculosis": "rare",
    },
    "north_america": {
        "dengue": "rare",
        "malaria": "rare",
        "typhoid": "rare",
        "tuberculosis": "rare",
    },
}

DEFAULT_REGION = "global"

# Set HEALTHBOT_REGION to one of REGION_TIERS to change the deployment's
# baseline. An unknown value logs and falls back rather than failing to start:
# a mistyped environment variable should not take triage offline.
ENV_REGION = "HEALTHBOT_REGION"


def available_regions() -> Iterable[str]:
    return sorted(REGION_TIERS)


def configured_region() -> str:
    """The region this process was started with."""
    return resolve_region(os.environ.get(ENV_REGION))


def resolve_region(region: Optional[str]) -> str:
    if not region:
        return DEFAULT_REGION
    key = region.strip().lower().replace("-", "_").replace(" ", "_")
    if key not in REGION_TIERS:
        logger.warning(
            "Unknown region %r; falling back to %r. Known regions: %s",
            region, DEFAULT_REGION, ", ".join(available_regions()),
        )
        return DEFAULT_REGION
    return key


def tier_of(disease: str, region: Optional[str] = None) -> str:
    """Prevalence tier for one disease under one region."""
    key = normalize_disease(disease)
    overrides = REGION_TIERS.get(resolve_region(region), {})
    if key in overrides:
        return overrides[key]
    return BASELINE_TIERS.get(key, DEFAULT_TIER)


def weight_of(disease: str, region: Optional[str] = None) -> float:
    return TIER_WEIGHTS[tier_of(disease, region)]


def weights(
    diseases: Iterable[str], region: Optional[str] = None
) -> Dict[str, float]:
    """Normalised prior over the given diseases: keys sum to 1.

    Normalising matters because the prior is combined with likelihoods in log
    space and then softmaxed; an unnormalised prior would still rank correctly
    but the reported probability would no longer be a probability.
    """
    resolved = resolve_region(region)
    raw = {}
    for disease in diseases:
        key = normalize_disease(disease)
        if key:
            raw[key] = weight_of(key, resolved)
    total = sum(raw.values())
    if not total:
        return {}
    return {disease: weight / total for disease, weight in raw.items()}


def unmapped(diseases: Iterable[str]) -> list:
    """Diseases with no explicit tier, which silently take DEFAULT_TIER.

    Called during knowledge-base validation so that adding a condition to the
    dataset without tiering it is visible in the logs instead of quietly
    scoring as uncommon forever.
    """
    return sorted(
        {normalize_disease(d) for d in diseases if d} - set(BASELINE_TIERS)
    )
