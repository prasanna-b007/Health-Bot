# What the knowledge base actually is

Written for anyone deciding how far to trust this engine's output — a
reviewer, a marker, a contributor, or the author in six months.

Everything Health-Bot knows about disease comes from four CSVs in
`backend/datasets/`. This document is about what is really in them, because
the honest description is less impressive than the obvious one and the
difference matters.

---

## The short version

| | |
|---|---|
| Conditions | 41 |
| Symptoms | 131 |
| Rows in `dataset.csv` | 4,920 |
| **Distinct symptom patterns** | **304** |
| Source | the public Kaggle "Disease Symptom Prediction" set |
| Provenance | no stated clinical source, no citation, no author |
| Validation | none, by anyone, ever |

The gap between 4,920 and 304 is the thing to understand.

---

## The 120-rows-per-disease trap

`dataset.csv` holds exactly 120 rows for each of its 41 conditions. That
reads like 120 observed cases, and the README used to say so: "120 cases per
disease, so how often a symptom accompanies a condition is measured rather
than assumed."

It is not true. Collapse the rows on their symptom sets and `Fungal infection`
has **five** distinct patterns; the other 115 rows are permutations and
leave-one-out variants of those five. The same holds across the file.

The consequence was not cosmetic. Scoring counted rows, so:

- **Frequencies measured the padding, not the medicine.** `P(itching | fungal
  infection)` came out as *how many permutations happened to include itching*.
- **The sample looked 16× larger than it is.** Laplace smoothing, which exists
  to stop thin evidence producing confident answers, was swamped: a prior of
  α=1 against 120 rows is nearly nothing, against 5 rows it does real work.
- **So the posterior was overconfident.** The UI showed percentages in the
  nineties for evidence that did not remotely support them.

`datastore._load_dataset` now indexes **distinct presentations**. The numbers
went down and got better: the same fungal-infection presentation that used to
score 97% now scores 88%, and a vague two-symptom report that used to name a
condition outright now returns "no single condition stands out".

---

## What the four files are

**`dataset.csv`** — condition → up to 17 symptoms per row. The membership
table above. Used for ranking.

**`Symptom-severity.csv`** — symptom → weight 1–7. Used *only* for risk
scoring and for deciding which question to ask next. Never for matching: how
dangerous a symptom is says nothing about which disease it implies. These
weights were re-curated by hand (`update_weights.py`, with a `--check` gate in
CI) because the originals had chest pain and breathlessness scoring below
skin rash.

**`symptom_Description.csv`** — one-line description per condition. Display
only.

**`symptom_precaution.csv`** — four terse fragments per condition ("stop
irritation", "avoid oily food"). Filtered on load: anything naming a drug, a
dose or an unsafe blanket remedy is dropped (`datastore._UNSAFE_ADVICE_TERMS`).
What survives is thin, which is why `actions/care_plan.py` carries authored,
non-pharmacological care plans instead.

---

## What is *not* in the data, and is supplied by us

Three things the engine needs that no CSV contains.

**Prevalence.** The dataset says nothing about how common anything is, so
ranking assumed all 41 conditions equally likely — AIDS competed with the
common cold on symptom fit alone. `actions/prevalence.py` supplies a coarse
four-tier prior, hand-assigned, with regional overrides. It is a judgement
call by a non-clinician and it is the single most opinionated file in the
repository. It is also, per the evaluation suite, the change that improved
results most.

**"None of the above".** The dataset has 41 answers and no way to say the
symptoms do not point anywhere. Most people who open a symptom checker have
something self-limiting and unnamed. `scoring.OTHER_DISEASE` competes as a
real candidate holding 30% of the prior, so declining to name a condition is
now a result rather than a failure.

**Care plans.** See `actions/care_plan.py`.

---

## What the evaluation numbers mean

`backend/tests/vignettes.yml` holds 36 presentations written in ordinary
English, replayed through the whole engine by `tests/test_evaluation.py`.
It gates CI on top-1 and top-3 accuracy, disposition accuracy, mean questions
asked, and total red-flag recall.

**These are regression numbers, not clinical validation.** The vignettes were
written by a non-clinician against the same knowledge base the engine scores
from. A perfect score means the engine behaves consistently with its own
data. It does not mean the engine is right about medicine, and the numbers
should not be quoted as though it did.

What the suite is genuinely good for is the thing unit tests cannot do:
catching a change to priors, smoothing or question selection that quietly
makes real presentations worse. It has already earned its place — building it
surfaced five defects that every unit test passed straight through:

1. `no chest pain, just a headache` **confirmed chest pain**, which drove the
   ranking, inflated the risk score and tripped the emergency screen. The
   negation logic lived in the red-flag detector and nowhere else.
2. Autocorrect rewrote words inside multi-word phrases — `keep needing to go`
   became `keep sneezing to go` — silently turning a urinary symptom into a
   respiratory one.
3. A textbook stroke description (`my speech is slurred and one side feels
   weak`) was missed entirely, because the phrase list only knew the noun
   form `slurred speech`.
4. Denials were weighted equally with confirmations, so the engine
   interrogated eight textbook presentations — a plain UTI among them — out of
   a correct answer and into "no single condition stands out".
5. Only 25 of 131 symptoms had any everyday phrasing, so `my joints are
   swollen and walking hurts` — three real arthritis symptoms in plain
   English — returned "I couldn't understand your symptoms".

---

## If you want to make this better

In descending order of how much it would matter:

1. **Replace the knowledge base.** Everything above is working around a
   teaching dataset. A source with real conditional frequencies and a
   citation would improve results more than any amount of modelling.
2. **Have a clinician review `prevalence.py` and `care_plan.py`.** Both are
   currently one non-clinician's judgement, clearly marked as such.
3. **Write vignettes from real presentations**, ideally by someone who has
   taken histories, and keep them separate from the ones written against this
   dataset.
4. **Model symptom correlation.** `scoring._TEMPERATURE` is a blunt
   correction for treating fever, chills and sweating as three independent
   observations. The principled fix is to model the dependence.

See also [INTENDED_USE.md](INTENDED_USE.md) for what this software is and is
not meant to be used for.
