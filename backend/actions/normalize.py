"""Canonical text forms shared by every module.

Symptom and disease names arrive from three CSVs and from free user text, each
with its own spelling of the same thing ("skin_rash", "skin rash", "Skin Rash",
"dischromic  patches" with a double space).  Normalising once, here, is what
lets the rest of the codebase compare strings with `==` instead of accumulating
per-site workarounds.
"""
import re
from typing import Optional

_WHITESPACE = re.compile(r"\s+")
_APOSTROPHES = re.compile(r"[\u2018\u2019'`]")

# Typos in the source CSVs that normalisation alone cannot reconcile.
# Keyed by the already-normalised form, so add entries in lowercase.
_SYMPTOM_FIXES = {
    "foul smell ofurine": "foul smell of urine",
    "dischromic patches": "dischromic patches",
}

# Columns in Symptom-severity.csv that are not symptoms.
NON_SYMPTOMS = {"prognosis", "symptom"}


def normalize(text: Optional[str]) -> str:
    """Lowercase, drop apostrophes, underscores to spaces, collapse whitespace.

    Apostrophes are removed rather than preserved so that "can't breathe" and
    "cant breathe" compare equal — emergency keyword matching depends on it.
    """
    if not text:
        return ""
    out = str(text).replace("_", " ").lower()
    out = _APOSTROPHES.sub("", out)
    return _WHITESPACE.sub(" ", out).strip()


def normalize_symptom(text: Optional[str]) -> str:
    """Canonical symptom key: normalised, with known CSV typos repaired."""
    key = normalize(text)
    return _SYMPTOM_FIXES.get(key, key)


def normalize_disease(text: Optional[str]) -> str:
    """Canonical disease key: normalised (trailing spaces in the CSVs vanish)."""
    return normalize(text)


def display(text: Optional[str]) -> str:
    """Human-facing form of a canonical key."""
    return normalize(text).title()
