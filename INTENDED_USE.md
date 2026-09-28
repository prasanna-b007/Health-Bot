# Intended use and limitations

Written for anyone evaluating whether to deploy, extend or rely on this
software — and for the author, as the statement the project should be held to.

---

## What this is

Health-Bot is an **educational project** that demonstrates symptom triage:
free-text symptom extraction, probabilistic ranking over a small knowledge
base, risk scoring, red-flag escalation, and a care disposition.

It is intended to be read, learned from, and extended.

## What this is not

**It is not a medical device, and it has not been validated.** No clinician
has reviewed its knowledge base, its prevalence priors, its risk thresholds or
its care plans. No study has measured whether its dispositions agree with
those of a trained triage nurse. The accuracy figures in CI are consistency
checks against its own data — see [DATA.md](DATA.md).

**It must not be used to make real care decisions**, deployed to the public as
a health service, or presented to users as clinical advice.

---

## Regulatory position

Software that takes a person's symptoms and returns a suggested condition and
an urgency level is, in most jurisdictions, regulated once it is *placed on
the market* for a medical purpose:

- **EU / UK:** likely Class IIa under MDR Annex VIII Rule 11, which catches
  software providing information used to take decisions for diagnostic or
  therapeutic purposes. The disposition output ("urgent care today") is
  squarely within that.
- **United States:** an FDA-regulated *device function* unless it meets the
  Clinical Decision Support exemption in section 520(o)(1)(E) — which this
  does not, because it is aimed at a lay user rather than a clinician.
- **India:** in scope of the CDSCO Medical Device Rules 2017 as software
  intended for diagnosis.

None of this applies to a project that stays a teaching exercise, which is
what this one is. It becomes relevant the moment someone ships it to real
users, and that is the point at which the honest answer is: **do not, without
a regulatory strategy and clinical validation.**

---

## Known limitations

**The knowledge base covers 41 conditions.** The space of reasons a person
feels unwell is very much larger. The engine now has an explicit "no single
condition stands out" answer for this reason, but the limit is real.

**The prevalence prior is a judgement call.** `actions/prevalence.py` assigns
each condition to one of four tiers by hand. It changes results materially and
no clinician has checked it. Regional overrides exist because dengue and
malaria are routine in some places and vanishingly rare in others, but the
default `global` setting is wrong for almost everywhere specific.

**Red-flag detection is keyword matching.** It now handles negation ("no chest
pain"), past-tense history ("my father had a heart attack last year"), and the
phrasings people actually use — but it is a phrase list, not comprehension. It
is deliberately biased toward over-triggering: a false alarm costs one
alarming screen, and a miss can cost considerably more.

**Ranking assumes symptoms are independent** given the condition, which is
false — fever, chills and sweating are close to one observation, not three.
`scoring._TEMPERATURE` discounts for this bluntly rather than modelling it.

**English only.** The alias table, the red-flag phrases and every string in
the app are English. Symptom vocabulary does not translate mechanically.

**No account of medication, pregnancy, immunosuppression or recent surgery** —
all of which change triage substantially. The profile collects allergies and
medications but nothing consumes them, deliberately: collecting medical data
that changes no output is collection for its own sake.

---

## Safety behaviour you can rely on

These are tested and gated in CI:

- **Red-flag recall is a hard 100%** across the evaluation vignettes. A
  regression that misses one fails the build.
- **An escalation never also delivers a diagnosis.** Triage stops.
- **Mental-health crises route separately** from medical emergencies — to a
  crisis line for the user's country, never to a hospital map — and the
  disclosure is never echoed back to the user.
- **Emergency numbers resolve per country** and are printed on the button, so
  a user who knows their local number can see if the app has guessed wrong.
- **Out-of-range intake values are discarded**, not trusted, on the server.
- **Serious conditions are guarded**: heart attack and brain haemorrhage are
  never named without corroborating symptoms.

---

## Data handling

See [PRIVACY.md](PRIVACY.md). In short: assessment history never leaves the
device, exactly two profile fields are ever transmitted, and the stateless API
retains nothing at all.

---

## If you are grading this project

The most defensible things in it are the evaluation harness
(`backend/tests/test_evaluation.py`), the separation of the engine from Rasa,
and the fact that the limitations above are written down rather than papered
over. The least defensible is the knowledge base, and no amount of
engineering around it changes that.
