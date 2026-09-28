# 🏥 Health-Bot 2.0

An AI-powered healthcare triage and assistance mobile application that helps users understand their symptoms, assess health risk, detect emergencies, and receive intelligent healthcare guidance through a conversational interface.

> **Goal:** Not to replace medical professionals — but to provide fast, accessible, and intelligent healthcare support anytime, anywhere.

---

## Problem Statement

Many people ignore early symptoms or search random information online, leading to confusion, misinformation, delayed treatment, and unnecessary panic.

Health-Bot bridges this gap through:

- ✅ Immediate symptom assessment
- ✅ Risk-level evaluation (Low / Moderate / High)
- ✅ Emergency detection and escalation
- ✅ Nearby hospital recommendations
- ✅ Preventive healthcare guidance

---

## Application Workflow

```
User opens app
    ↓
Enters symptoms → "I have fever and headache"
    ↓
Context collection → Age, Duration, Severity
    ↓
AI Follow-up questions → "Are you also experiencing chills?"
    ↓
Red-flag check → Chest pain? → ⚠️ EMERGENCY   |   "end my life"? → CRISIS LINE
    ↓
Disease Ranking → Naive Bayes with a prevalence prior, or "none of these"
    ↓
Risk Assessment → Low / Moderate / High
    ↓
Disposition → Now / Today / Within 72h / Self-care
    ↓
Results Screen → Disposition FIRST, then condition, risk, care plan
    ↓
Saved to history → Kept on the device, replayable from Home
    ↓
Hospital Recommendation → Nearby facilities + directions
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter |
| AI Chat Engine | Rasa Open Source |
| Triage Engine | Plain Python (no Rasa dependency) |
| Backend Actions | Python (Rasa SDK) |
| Hospital Services | Geoapify Places API |
| Messaging | Telegram Bot API *(planned)* |

---

## Interface

The app is light, quiet and mostly grey. Someone opening a symptom checker is
usually worried and in a hurry, so the interface tries to be legible and
uneventful rather than impressive — the arrangement of a printed form, which
people already know how to read.

| Element | Rule |
|---|---|
| Canvas | Warm paper `#F7F6F2`; content sits on plain white cards |
| Depth | A 1px hairline and a whisper of shadow. No glows, no gradients |
| Colour | Grey is the default. Colour means a risk level, a live state, or the one action the screen is for |
| Signal | Deep pine `#15695A` for the primary action, focus and selection |
| Ember | `#B23A2C` is reserved for emergency, so seeing it always means one thing |
| Type | Inter throughout, at one size scale. Measured values get tabular figures |

There is one filled card in the whole app — "Check my symptoms" on the home
screen. Hierarchy is carried by that fill rather than by size or decoration,
which is why nothing else needs to shout.

Motion is spring-driven and interruptible, and stays under the platform's
"Reduce Motion" setting.

### Accessibility

The app had no `Semantics` anywhere in `lib/`. Every tappable surface is built
on `Pressable` or `AppButton`, and both used a bare `GestureDetector` — which
exposes a tap action but no *role* — so TalkBack and VoiceOver read the entire
interface as flat text. There was no way to tell a label from the button that
dismisses an emergency screen, and icon-only controls, including every back
arrow, had no name at all.

For an app whose users are by definition unwell, and skew older, that is not a
nice-to-have. What is now guaranteed and tested
([`accessibility_test.dart`](health_bot_app/test/accessibility_test.dart),
using Flutter's own `meetsGuideline` checks rather than hand-rolled ones):

- Every button announces its role and its enabled state.
- Every icon-only control has a name.
- Tap targets are ≥ 48×48 — Android's guideline, not iOS's 44, since the
  larger of the two is the one to build.
- The risk meter reads as one value ("Risk level: High, 3 out of 4") rather
  than four anonymous rectangles.
- Text contrast passes, and the layout survives 200% text scaling.

### On-device memory

Two things are remembered locally, in `SharedPreferences`:

- **Health profile** — name, age, sex, conditions, allergies, medications.
  Every field is optional and the app works unchanged when the profile is empty.
- **Assessment history** — the most recent 40 results, shown as a timeline on
  Home and replayable in full. Records store the whole result rather than a
  reference, because triage sessions are stateful on the backend and cannot be
  re-fetched afterwards. **History never leaves the device.**

### What is sent, and why

Exactly two profile fields travel, with an assessment and only with an
assessment. Anything sent has to earn it by changing the result:

| Field | Sent | Why |
|---|---|---|
| Age | ✅ | Prefills the form the user confirms by hand; shifts the risk score |
| Ongoing conditions | ✅ | Feed comorbidity scoring — see below |
| Name, sex, allergies, medications | ❌ | No engine rule consumes them |
| Assessment history | ❌ | Never leaves the device |

### Safety behaviour

Five things a symptom checker has to get right, and how this one does:

- **Mental-health crises are not medical emergencies.** "I want to end my
  life" used to match the same keyword list as chest pain and produce the same
  answer — directions to the nearest emergency department. It now routes to
  [`crisis_screen.dart`](health_bot_app/lib/screens/crisis_screen.dart): the
  crisis line for the user's country, a calm palette rather than the emergency
  red, no further questions, and the disclosure is never repeated back to
  them. Where the country is unknown the app says so and offers a directory,
  because dialling a guessed number at that moment is worse than admitting it.
- **A denied symptom is not a reported one.** "No chest pain, just a headache"
  used to *confirm chest pain* — which ranked the user against cardiac
  conditions, raised their risk score and tripped the emergency screen. The
  negation logic existed in the red-flag detector and nowhere else, so the
  detector correctly declined to escalate a sentence the extractor had already
  escalated for it. Both now share the same clause-scoped negation
  ([`text_utils.py`](backend/actions/text_utils.py)), and past-tense history
  ("my father had a heart attack last year") is filtered too — but never the
  *subject*: "my father is having chest pain" still escalates, because someone
  using this on another person's behalf needs the emergency screen.

- **Emergency number** — resolved per country from the device locale
  ([`emergency_number.dart`](health_bot_app/lib/util/emergency_number.dart)),
  preferring the ambulance line where one exists (911 US, 999 UK, 000 AU,
  119 JP, 192 BR), falling back to the GSM-routed 112. The resolved number is
  printed on the button, so a user who knows their local number can see if the
  app has guessed wrong.
- **Offline red flags** — the real detector is
  [`emergency.py`](backend/actions/emergency.py), but when the server is
  unreachable the app runs a subset of the same phrase list on-device
  ([`red_flags.dart`](health_bot_app/lib/services/red_flags.dart)). It only
  ever escalates: a hit routes to emergency guidance, a miss leaves the
  network error alone. A miss never means "you are fine".
- **Comorbidity scoring** —
  [`comorbidity.py`](backend/actions/comorbidity.py) raises the risk score for
  recognised chronic conditions, and raises it much further when a condition
  is paired with a symptom that condition makes dangerous. Asthma alongside
  confirmed breathlessness carries a Moderate presentation to High, which
  changes the advice from "consult a doctor" to "within 24 hours". Points are
  per vulnerability *group* and capped, so a long profile cannot inflate its
  own risk level. A user with no profile scores exactly as before.

---

## Project Structure

```
Health-Bot/
├── backend/                    # Rasa backend
│   ├── actions/
│   │   ├── actions.py          # Rasa adapter — the only module importing rasa_sdk
│   │   ├── triage.py           # Conversation state machine + risk scoring
│   │   ├── comorbidity.py      # Chronic conditions as a risk modifier
│   │   ├── scoring.py          # Naive Bayes ranking, confidence bands
│   │   ├── emergency.py        # Red-flag detection
│   │   ├── datastore.py        # CSV loading, normalisation, validation
│   │   ├── text_utils.py       # Symptom extraction, aliases, typo correction
│   │   ├── normalize.py        # Canonical symptom/disease names
│   │   ├── prevalence.py       # How likely each condition is, before evidence
│   │   ├── care_plan.py        # Non-medication care plans per condition
│   │   ├── specialists.py      # Disease → specialist referral
│   │   ├── reason_map.py       # Why each question is asked
│   │   └── config.py           # Thresholds
│   ├── api/                    # Stateless FastAPI service (no Rasa)
│   │   ├── main.py             # Routes, rate limiting, auth
│   │   └── state.py            # Signed conversation state held by the client
│   ├── data/                   # nlu.yml, rules.yml, stories.yml
│   ├── datasets/               # CSV knowledge base
│   ├── tests/                  # pytest suite (no server required)
│   │   ├── vignettes.yml       # 36 presentations, with expected outcomes
│   │   └── test_evaluation.py  # Replays them; gates CI on measured quality
│   ├── domain.yml
│   └── update_weights.py       # Idempotent severity-weight maintenance
│
├── health_bot_app/             # Flutter mobile application
│   ├── lib/
│   │   ├── config/app_config.dart   # Build-time config (--dart-define)
│   │   ├── models/          # Assessment data, hospitals, profile, history records
│   │   ├── motion/          # Spring primitives, press feedback, reduce-motion
│   │   ├── screens/
│   │   ├── services/        # Rasa/API, location, hospitals, on-device store
│   │   ├── theme/           # Palette, shape and spacing tokens, type scale
│   │   ├── util/            # Greeting, dates, emergency numbers, crisis lines
│   │   └── widgets/         # Shared card/heading/pill/top bar, inputs, meters
│   └── test/                   # Widget, model and service tests
│
├── docker-compose.yml          # Rasa server + action server (+ api profile)
├── DEPLOYMENT.md               # Production deployment guide
├── DATA.md                     # What the knowledge base actually is
├── INTENDED_USE.md             # Intended use, limitations, regulatory position
├── PRIVACY.md                  # What is stored, what is sent, what is kept
└── .github/workflows/
    ├── ci.yml                  # Tests, image build, secret scan
    └── release.yml             # Signed app bundle + published images
```

---

## How to Run

### Prerequisites

- Python 3.7–3.10 (Rasa 3.x does not support newer versions)
- Flutter SDK
- Android Studio / Emulator (or physical device)
- A [Geoapify](https://www.geoapify.com/) API key for hospital search (free tier is enough)

### Step 1 — Train the model

Required on first run and after any change to `domain.yml`, `data/`, or `config.yml`:

```powershell
cd d:\Projects\Health-Bot\backend
.\venv\Scripts\activate
rasa train
```

### Step 2 — Start the Rasa Action Server

```powershell
cd d:\Projects\Health-Bot\backend
.\venv\Scripts\activate
python -m rasa run actions
```

### Step 3 — Start the Rasa API Server

```powershell
cd d:\Projects\Health-Bot\backend
.\venv\Scripts\activate
python -m rasa run --enable-api --cors "*" --port 5005
```

### Step 4 — Configure and run the Flutter app

Configuration is passed at build time, so no machine-specific address or API
key is committed. Copy the example file and fill it in:

```powershell
cd d:\Projects\Health-Bot\health_bot_app
copy env.example.json env.json     # env.json is gitignored
flutter pub get
flutter run --dart-define-from-file=env.json
```

`env.json`:

```json
{
  "RASA_BASE_URL": "http://10.0.2.2:5005",
  "RASA_AUTH_TOKEN": "",
  "PLACES_API_KEY": "your_geoapify_key",
  "HOSPITAL_SEARCH_RADIUS_M": 5000
}
```

`RASA_AUTH_TOKEN` may stay empty for local development. It is required against
a deployed backend, which will not start without one.

| Platform | `RASA_BASE_URL` |
|---|---|
| Android Emulator | `http://10.0.2.2:5005` *(default)* |
| Physical Device | `http://<your-PC-IP>:5005` |
| Flutter Web | `http://localhost:5005` |

> A key compiled into a mobile binary is extractable by anyone holding the app.
> `--dart-define` keeps it out of version control, which is a different problem
> from keeping it out of the build. If quota matters, proxy the places lookup
> through your own backend.

---

## Deployment

The backend runs as two containers — a Rasa server with the model baked in,
and a much smaller action server carrying only the triage engine:

```bash
cp .env.example .env      # set RASA_AUTH_TOKEN
docker compose up --build
```

**[DEPLOYMENT.md](DEPLOYMENT.md)** covers signing the Android app, TLS, the
reverse-proxy configuration, and what this setup deliberately does not do.

### The lighter alternative: a stateless API

Rasa is used here as an intent router and nothing else. Every rule maps one
intent straight to one custom action, all thirteen intents are yes / no /
symptom text / small talk, and every decision lives in `actions/`, which
imports no Rasa at all. For that routing you pay the TensorFlow stack, a hard
Python ≤ 3.10 pin, hundreds of megabytes of model artefacts, a 90-second
healthcheck start period, and a retrain on every `domain.yml` edit.

[`backend/api/`](backend/api/) is the same engine behind ~200 lines of
FastAPI:

```bash
docker compose --profile api up --build      # or:
pip install -r backend/requirements-api.txt
uvicorn api.main:app --port 8000
```

| | Rasa stack | Stateless API |
|---|---|---|
| Python | ≤ 3.10 only | 3.9 – 3.13 |
| Install size | ~2 GB | tens of MB |
| Cold start | ~90 s | ~1 s |
| Conversation state | in-memory tracker | signed, held by the client |
| Horizontal scaling | broken — turn 2 hits a process that never saw turn 1 | works, nothing shared |
| Rate limiting | none | per-client |
| Retains your symptoms | for the session | never |

It is deliberately **additive** — nothing here imports Rasa, both stacks run
the identical engine, and CI runs the full engine suite on both Python 3.10
and 3.12 to prove it. The missing tracker store is the part worth taking
seriously even if you stay on Rasa: `endpoints.yml` configures none, so a
restart loses every assessment in flight and a second replica breaks triage
outright.

---

## Testing

```powershell
# Backend — 472 tests, no server needed
cd backend
pip install -r requirements-dev.txt
pytest

# Flutter — 135 tests
cd health_bot_app
flutter test
flutter analyze
```

End-to-end tests against a running server are opt-in:

```powershell
$env:HEALTHBOT_LIVE_URL = "http://localhost:5005"
pytest tests/test_live_server.py
```

---

## Key Features

### 🔍 Intelligent Symptom Assessment
Extracts symptoms from natural language, handles typos and everyday phrasings ("my joints hurt", "running a fever"), and asks follow-up questions chosen to be maximally informative — the symptom the leading candidates most disagree about.

### ⚖️ Probabilistic Disease Ranking
`dataset.csv` holds 120 rows per condition — but collapsed on their symptom
sets those are only **304 distinct presentations across all 41 conditions**,
the rest being permutation padding. Scoring counts the distinct patterns, not
the rows; counting rows measured how the file was padded and made the sample
look 16× larger than it is, which drove the posterior to unearned confidence.
[DATA.md](DATA.md) is the full account. Ranking is a naive Bayes posterior
over those frequencies, against a prevalence prior:

- **Yes** contributes `log P(symptom | disease)`
- **No** contributes `log (1 − P(symptom | disease))`, at 45% weight — denials
  are real evidence, but the dataset lists the *union* of symptoms ever seen
  with a condition and no real patient has all of them, so absence is the
  normal case rather than a contradiction. At equal weight the engine
  interrogated textbook presentations out of a correct answer.
- **Not sure** contributes nothing — missing data, not evidence of absence

Two things the dataset cannot supply are supplied by us:

- **A prevalence prior** ([`prevalence.py`](backend/actions/prevalence.py)).
  Ranking used to assume all 41 conditions equally likely, so AIDS competed
  with the common cold on symptom fit alone. Four coarse tiers, with regional
  overrides — dengue, typhoid, malaria and tuberculosis are routine
  presentations in South Asia and vanishingly rare in Europe, so a single
  global table would be wrong for most users either way. Set `HEALTHBOT_REGION`.
- **"None of these."** The model had 41 answers and no way to say the symptoms
  do not point anywhere, so it named something every single time. An
  `unspecified illness` candidate holding 30% of the prior now competes on
  merit: it wins for "tired and a headache" and loses to any presentation the
  evidence actually singles out.

Results are presented as a band (**Likely / Possible / Unclear**) rather than a bare percentage, because a number from a 41-condition teaching dataset does not carry clinical precision.

### 🧭 Disposition-first results
The headline of a result is **what to do and how soon** — *Emergency care now
/ Urgent care today / See a doctor soon / Self-care and monitor* — and the
condition name is the supporting detail. That is a reversal of how the app
used to present an assessment, and the reason is not cosmetic: naming one
condition out of 41 from a teaching dataset is the least reliable thing this
engine does, while working out whether someone should be seen today rests on
severity, age, duration and comorbidity and is the part it has the best claim
to be right about. Leading with the disposition puts the trustworthy half of
the answer first — and it is the half a worried person can act on.

Each result also names **the one symptom that would change it** ("if you also
had shortness of breath, this would point to pneumonia instead"), which is the
cheapest honesty available to a model working from five yes/no questions.

### 📊 Risk Assessment Engine
Evaluates risk from symptom severity, patient age, symptom duration, the
danger weight of the reported symptoms, and two interactions the evaluation
suite caught it missing — a severe self-report *alongside* a dangerous symptom,
and prolonged illness at a vulnerable age. Both were under-triage: an 8/10
fever with a high-weight symptom landed six points below the High threshold,
and three weeks of productive cough scored the same at 74 as at 30.

### 🚨 Emergency Detection
Watches both what the user types *and* what they confirm during questioning, so a red flag reached through a yes/no answer escalates just as a typed one does. Triggers on chest pain, breathing difficulty, severe bleeding, stroke signs, anaphylaxis and more — and now on the phrasings people actually use, after the evaluation suite found *"my speech is slurred and one side feels weak"* sailing past a list that only knew the noun form.

Mental-health crises route to a crisis line instead, never to a hospital map.

### 🧪 Measured, not asserted
[`tests/vignettes.yml`](backend/tests/vignettes.yml) holds 36 presentations
written in ordinary English; `test_evaluation.py` replays each through the
whole engine and gates CI on top-1 and top-3 accuracy, disposition accuracy,
questions asked, and **100% red-flag recall**. Building it surfaced five
defects that every unit test passed straight through — see
[DATA.md](DATA.md). The numbers are regression baselines, not clinical
validation, and DATA.md says so at length.

### 🏥 Hospital Recommendations
The device performs the nearby-facility search, since it is the only party that knows where the user is. The backend signals when a search is warranted; the app queries Geoapify and sorts by distance.

### 💉 Vaccination Guidance
Schedules for newborns, children, pregnant women, and adults.

---

## API Communication

Flutter communicates with Rasa via `POST /webhooks/rest/webhook`:

```json
{
  "sender": "flutter_1719068400_42",
  "message": "I have fever and headache",
  "metadata": { "age": 22, "duration": 5, "severity": 8 }
}
```

A follow-up question:

```json
[{
  "recipient_id": "flutter_1719068400_42",
  "text": "Are you also noticing any Chills?",
  "custom": {
    "type": "question",
    "question": "Are you also noticing any Chills?",
    "reason": "Chills often occur with infections such as malaria and dengue.",
    "question_number": 1,
    "estimated_total": 5,
    "input_type": "yes_no"
  }
}]
```

A result:

```json
[{
  "custom": {
    "type": "result",

    "disposition": "urgent_today",
    "disposition_label": "Urgent care today",
    "disposition_timeframe": "Within 24 hours",
    "disposition_detail": "See a doctor today, or go to an urgent care centre if you cannot get an appointment.",

    "top_condition": "Dengue",
    "is_unspecified": false,
    "confidence": 71,
    "confidence_band": "likely",
    "confidence_label": "Likely match",
    "risk": "high",
    "risk_score": 65,
    "risk_factors": ["High symptom severity (8/10)", "Severe presentation of a high-risk symptom"],
    "recommended_action": "See a doctor today, or go to an urgent care centre if you cannot get an appointment.",
    "matched_symptoms": ["High Fever", "Chills", "Headache"],
    "ruled_out_symptoms": ["Vomiting"],
    "alternatives": [{"name": "Malaria", "confidence": 13, "band": "unclear"}],
    "changes_answer": {"symptom": "Sweating", "condition": "Malaria"},
    "advice": ["Consult nearest hospital", "Stay hydrated and get adequate rest"],
    "care_plan": {
      "goal": "Stay hydrated and catch the danger window, which is when the fever drops.",
      "do": ["Drink far more fluid than usual", "Rest completely"],
      "avoid": ["Aspirin and anti-inflammatory painkillers, which raise the bleeding risk in dengue"],
      "red_flags": ["Bleeding gums or nose", "Severe abdominal pain or persistent vomiting"]
    },
    "specialist": {"name": "General Physician", "department": "General Medicine", "priority": "Immediate"},
    "questions_asked": 3,
    "disclaimer": "This is not a medical diagnosis. Please consult a qualified healthcare professional."
  }
}]
```

`disposition` is the headline and `top_condition` the supporting detail —
see *Disposition-first results* above. When the evidence does not single out a
condition, `is_unspecified` is `true` and `top_condition` reads *"No single
condition stands out"*; the disposition still applies and is still the answer.

Other `type` values: `emergency`, `clarification`, `hospitals`.

An escalation carries a `category` that decides where the app sends the user:

```json
[{ "custom": {
  "type": "emergency", "emergency": true,
  "category": "crisis", "crisis": true,
  "reason": null,
  "disposition": "emergency", "disposition_label": "Talk to someone now"
}}]
```

`category` is `"emergency"` (→ hospital finder) or `"crisis"` (→ crisis line).
For a crisis, `reason` is always `null`: the matched phrase is the most
sensitive thing the user typed and is never echoed back, nor logged.

---

## Future Enhancements

- 🎙️ Voice-Based Healthcare Assistant
- 🌐 Regional Language Support
- 📋 Medical Report Analysis
- ⌚ Wearable Device Integration
- 📹 Telemedicine Integration
- 📅 Appointment Booking System

---

## Honest documentation

Three files that say what this project is rather than what it would like to be:

- **[DATA.md](DATA.md)** — what the knowledge base actually contains, why
  "120 cases per disease" was never true, and the five real defects the
  evaluation harness found.
- **[INTENDED_USE.md](INTENDED_USE.md)** — intended use, known limitations,
  and where this would sit under EU MDR / FDA / CDSCO if anyone shipped it.
- **[PRIVACY.md](PRIVACY.md)** — what stays on the device (almost everything),
  what travels (two fields), and what the server keeps (nothing, on the
  stateless API).

---

## Disclaimer

> *This application is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of a qualified healthcare provider.*

> **This is an educational project.** It has not been clinically validated, no
> clinician has reviewed its knowledge base or its risk thresholds, and it is
> not a medical device. See [INTENDED_USE.md](INTENDED_USE.md).
