# Health-Bot backend

Rasa action server plus the triage engine that drives it.

## Architecture

The triage logic is deliberately separate from Rasa. Only `actions.py` imports
`rasa_sdk`; everything it delegates to is plain Python, which is what lets the
whole decision path be tested without an action server, a tracker or a network.

| Module | Responsibility | Imports Rasa? |
|---|---|---|
| `actions/actions.py` | Adapter: Rasa slots ⇄ `TriageState`, dispatching | **yes** |
| `actions/triage.py` | Conversation state machine, risk scoring, result payload | no |
| `actions/scoring.py` | Naive Bayes disease ranking, confidence bands, question selection | no |
| `actions/emergency.py` | Red-flag detection in text and in confirmed symptoms | no |
| `actions/datastore.py` | CSV loading, normalisation, validation | no |
| `actions/text_utils.py` | Symptom extraction, aliases, typo correction | no |
| `actions/normalize.py` | Canonical forms for symptom and disease names | no |
| `actions/specialists.py` | Disease → specialist referral table | no |
| `actions/reason_map.py` | Why each follow-up question is being asked | no |
| `actions/config.py` | Thresholds | no |

### How ranking works

`dataset.csv` holds 120 recorded cases for each of 41 diseases, so
P(symptom | disease) is measured from row frequencies rather than guessed.
Ranking is a naive Bayes posterior over those frequencies with Laplace
smoothing:

* **Confirmed** symptoms contribute `log P(s | d)`.
* **Denied** symptoms contribute `log (1 - P(s | d))` — answering "no" is
  evidence, and it changes the result.
* **Unsure** answers contribute nothing; they are missing data, not absence.

The posterior is mapped to a band (`likely` / `possible` / `unclear`) and the
band is what the UI leads with. The raw percentage is still in the payload for
the meter, but a figure derived from a 41-condition teaching dataset should not
be presented as clinical precision.

Symptom **severity weights** (`Symptom-severity.csv`) play no part in ranking.
They describe how dangerous a symptom is, which drives risk assessment only.

## Setup

Python 3.8–3.10 (Rasa 3.6 does not support newer versions).

```powershell
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

Versions are pinned. Rasa 3.6 constrains many transitive packages tightly —
notably `packaging<21.0`, which pytest 8+ violates, so `requirements-dev.txt`
pins `pytest<8`. Installing an unpinned pytest into this environment silently
breaks Rasa.

## Running

The domain gained `denied_symptoms` and `emergency_reason` slots, so **retrain
before the first run**:

```powershell
rasa train
```

Then, in two terminals with the venv activated:

```powershell
python -m rasa run actions
```

```powershell
python -m rasa run --enable-api --cors "*" --port 5005
```

> The API server binds without authentication and with permissive CORS. That is
> fine on a development machine and is not suitable for anything reachable from
> a network you do not control.

## Containers

Two images, split along the Rasa boundary:

| File | Builds | Contains |
|---|---|---|
| `Dockerfile` | Rasa server | Rasa + TensorFlow + the model, trained at build time |
| `Dockerfile.actions` | Action server | `rasa-sdk` + the triage engine — no TensorFlow, ~250 MB |

The action-server image runs an import-time assertion during the build, so a
malformed CSV or a broken action class fails the build rather than the first
user message.

From the repository root:

```bash
cp .env.example .env      # set RASA_AUTH_TOKEN
docker compose up --build
```

See [DEPLOYMENT.md](../DEPLOYMENT.md) for the production configuration.

## Testing

```powershell
pip install -r requirements-dev.txt
pytest
```

162 tests run in under a second and need **no server** — the engine modules are
importable on their own. The Rasa adapter is covered by the opt-in end-to-end
suite:

```powershell
# with both servers running
$env:HEALTHBOT_LIVE_URL = "http://localhost:5005"
pytest tests/test_live_server.py
```

Rasa's own story tests still work as before:

```powershell
rasa test --stories tests/test_stories.yml
```

## Maintaining the severity weights

`Symptom-severity.csv` is the single source of truth for symptom danger.
`update_weights.py` applies the curated `OVERRIDES` table to it and is
idempotent — running it twice does the same as running it once.

```powershell
python update_weights.py --check     # CI: fail if the file has drifted
python update_weights.py --dry-run   # show what would change
python update_weights.py             # write
```

## Datasets

| File | Contents |
|---|---|
| `dataset.csv` | 4 920 case rows: disease + observed symptoms |
| `Symptom-severity.csv` | Symptom → severity weight (1–5) |
| `symptom_Description.csv` | Disease → plain-language description |
| `symptom_precaution.csv` | Disease → precautions (filtered; see below) |

Precaution rows are filtered on load: anything prescriptive (drug names,
"take antibiotics", surgery, vaccines) is dropped, spelling is repaired, and
general safety advice is appended. `datastore.GENERAL_ADVICE` is the fallback
when nothing in a row survives.
