"""Apply curated severity weights to datasets/Symptom-severity.csv.

Run from the backend directory:

    python update_weights.py --check     # report drift, change nothing
    python update_weights.py --dry-run   # show the diff
    python update_weights.py             # write the file

Idempotent by construction: it sets the symptoms named in OVERRIDES to their
declared weight and leaves every other row untouched, so running it twice is
the same as running it once. The previous version also rewrote any unlisted
weight above 3 down to 2, which meant each run degraded rows the run before it
had already lowered -- weights drifted downward every time it was invoked.

Symptom-severity.csv is the single source of truth for symptom danger, which
drives risk assessment. It has no part in disease matching; that is estimated
from case frequencies in dataset.csv (see actions/scoring.py).
"""
import argparse
import csv
import os
import sys

from actions.normalize import normalize_symptom

SEVERITY_PATH = os.path.join(os.path.dirname(__file__), "datasets", "Symptom-severity.csv")

# Curated weights on a 1-5 scale, keyed by canonical symptom name.
# 5 = immediately life-threatening, 1 = general discomfort.
OVERRIDES = {
    # Life-threatening
    "chest pain": 5,
    "breathlessness": 5,
    "blood in sputum": 5,
    "altered sensorium": 5,
    "slurred speech": 5,
    "weakness of one body side": 5,
    "acute liver failure": 5,
    # Urgent
    "stomach pain": 4,
    "high fever": 4,
    "stiff neck": 4,
    "yellowing of eyes": 4,
    "swelling of stomach": 4,
    # Moderate
    "vomiting": 3,
    "diarrhoea": 3,
    "dehydration": 3,
    # Mild
    "nausea": 2,
    "mild fever": 2,
    "cough": 2,
    "skin rash": 2,
    "burning micturition": 2,
    "headache": 1,
    "itching": 1,
    "fatigue": 1,
    "runny nose": 1,
    "joint pain": 1,
}


def read_rows(path):
    with open(path, encoding="utf-8") as handle:
        return list(csv.reader(handle))


def plan(rows):
    """Return (row_index, symptom, old, new) for every row that would change."""
    changes = []
    for index, row in enumerate(rows[1:], start=1):
        if not row:
            continue
        symptom = normalize_symptom(row[0])
        if symptom not in OVERRIDES:
            continue
        new = OVERRIDES[symptom]
        old = row[1].strip() if len(row) > 1 else ""
        if old != str(new):
            changes.append((index, symptom, old, new))
    return changes


def unknown_overrides(rows):
    """Override keys with no matching row -- almost always a typo."""
    present = {normalize_symptom(row[0]) for row in rows[1:] if row}
    return sorted(set(OVERRIDES) - present)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="exit non-zero if the file differs from OVERRIDES")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the changes without writing")
    args = parser.parse_args(argv)

    rows = read_rows(SEVERITY_PATH)

    missing = unknown_overrides(rows)
    if missing:
        print("WARNING: no row in the CSV for: {}".format(", ".join(missing)), file=sys.stderr)

    changes = plan(rows)
    if not changes:
        print("Severity weights already match OVERRIDES; nothing to do.")
        return 1 if missing else 0

    for _, symptom, old, new in changes:
        print("  {:<32} {} -> {}".format(symptom, old or "(blank)", new))

    if args.check:
        print("{} weight(s) differ from OVERRIDES.".format(len(changes)), file=sys.stderr)
        return 1
    if args.dry_run:
        print("Dry run: {} weight(s) would change.".format(len(changes)))
        return 0

    for index, _, _, new in changes:
        rows[index][1] = str(new)
    with open(SEVERITY_PATH, "w", encoding="utf-8", newline="") as handle:
        csv.writer(handle).writerows(rows)
    print("Updated {} weight(s) in {}.".format(len(changes), SEVERITY_PATH))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
