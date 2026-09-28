# Running Health-Bot locally

Step-by-step, from a fresh clone to a working app. Three processes have to be
running at once, in this order:

```
Action server  :5055   ← triage engine, dataset, risk scoring
Rasa API       :5005   ← NLU + dialogue, calls the action server
Flutter app            ← talks to :5005
```

Each gets its own terminal and stays open. Nothing here is a background
service — closing a terminal stops that piece.

---

## 0. Prerequisites

| Need | Version | Check with |
|---|---|---|
| Python | **3.8–3.10 only** | `python --version` |
| Flutter SDK | 3.x | `flutter --version` |
| Geoapify API key | free tier | *optional — hospital search only* |

> **Python 3.11+ will not work.** Rasa 3.6 pins `packaging<21.0` and a TensorFlow
> build that has no wheels above 3.10. If `python --version` is newer, install
> 3.10 alongside it and use that interpreter's full path in Step 1.

For a device target, also install Android Studio + an emulator. If you have
neither an emulator nor a phone, use the Chrome target — covered in Step 5.

---

## 1. Backend virtualenv

`venv/` is gitignored, so a fresh clone has none. From the repo root:

```powershell
cd backend
py -3.10 -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

Installing pulls the TensorFlow stack — expect several minutes and ~2 GB.

Leave this venv activated for Steps 2–4. Every backend terminal you open
needs `.\venv\Scripts\activate` first.

---

## 2. Train the model

`backend/models/` is gitignored too, so **a fresh clone has no model and the
server in Step 4 will refuse to start without one.** This step is mandatory
the first time:

```powershell
rasa train
```

Takes roughly 5–15 minutes and writes `models/<timestamp>-<name>.tar.gz`.
The server always loads the newest file in that directory.

Re-run this **only** after editing `domain.yml`, `data/`, or `config.yml`.
Changes to anything under `actions/` need no retraining — just restart the
action server.

---

## 3. Start the action server — terminal 1

```powershell
cd backend
.\venv\Scripts\activate
python -m rasa run actions
```

Wait for the knowledge base line — it confirms the CSVs parsed:

```
Knowledge base loaded: 41 diseases, 131 symptoms, 4920 case rows
Action endpoint is up and running on http://0.0.0.0:5055
```

If the disease or symptom count is zero, the dataset failed to load and
every assessment will come back empty. Fix that before continuing.

---

## 4. Start the Rasa API server — terminal 2

```powershell
cd backend
.\venv\Scripts\activate
python -m rasa run --enable-api --cors "*" --port 5005
```

Startup is slow — it imports TensorFlow, then unpacks the ~21 MB model. A
minute or more of deprecation warnings is normal. Wait for:

```
Rasa server is up and running.
```

`--cors "*"` is needed for the Flutter **web** target and is fine locally.
Never use it on a deployment reachable from the internet — see
[DEPLOYMENT.md](DEPLOYMENT.md).

### Verify the two servers are actually talking

Before touching the app, confirm the round trip. In a third terminal:

```powershell
$body = '{"sender":"smoke","message":"I have fever and headache","metadata":{"age":22,"duration":5,"severity":8}}'
Invoke-RestMethod -Uri http://localhost:5005/webhooks/rest/webhook `
  -Method Post -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 5
```

A working stack returns a follow-up question — the engine has read the
symptoms and is now narrowing down:

```
value : {@{recipient_id=smoke; text=Let me check one more thing — do you also
        have **Malaise**?}, @{recipient_id=smoke; custom=}}
Count : 2
```

The `custom` payload carries `type=question`, the reason the question is being
asked, and `question_number` / `estimated_total`. (Windows PowerShell wraps
arrays in `value` / `Count` — that is the shell, not the response.)

An empty response means the Rasa server is up but **cannot reach the action
server** — check terminal 1 and that `backend/endpoints.yml` points at
`http://localhost:5055/webhook`.

---

## 5. Run the Flutter app — terminal 3

Configuration is passed at build time so no address or API key is committed.
`env.json` is gitignored; create it from the example:

```powershell
cd health_bot_app
copy env.example.json env.json
flutter pub get
```

Set `RASA_BASE_URL` in `env.json` to match your target — **this is the single
most common reason the app runs but never gets a reply:**

| Target | `RASA_BASE_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:5005` |
| Physical device | `http://<your-PC-LAN-IP>:5005` |
| Chrome / web | `http://localhost:5005` |

`10.0.2.2` is the emulator's alias for the host machine. It is meaningless in
a browser, and `localhost` inside an emulator points at the emulator itself.

`RASA_AUTH_TOKEN` stays empty locally. `PLACES_API_KEY` may stay empty — see
[Optional](#optional-hospital-search) below.

Then launch:

```powershell
# Android emulator or attached device
flutter run --dart-define-from-file=env.json

# No emulator installed? Use Chrome instead
flutter run -d chrome --web-port=8088 --dart-define-from-file=env.json
```

Check what's available first with `flutter devices` and `flutter emulators`.
The web build is a genuine fallback — the UI is mobile-first, so narrow the
window or switch on Chrome's device emulation to see it as designed.

---

## Optional: hospital search

Everything above works without a key. The one feature that does not is
**nearby hospitals**, which the device queries directly from Geoapify.

Get a free key at [geoapify.com](https://www.geoapify.com/), put it in
`env.json` as `PLACES_API_KEY`, and **restart** the app — `--dart-define`
values are baked in at build time, so a hot reload will not pick up the
change.

Browsers and emulators also need location permission granted, and an emulator
reports no position until you set one in its extended controls.

---

## Stopping

`Ctrl+C` in each terminal. In the Flutter terminal, `q` quits and detaches
cleanly; `r` hot reloads and `R` hot restarts while you work.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No model found` on Step 4 | Never trained; `models/` is gitignored | Run `rasa train` (Step 2) |
| Webhook returns `[]` | Action server down or unreachable | Start Step 3; check `endpoints.yml` |
| App sends, nothing comes back | Wrong `RASA_BASE_URL` for the target | See the table in Step 5 |
| CORS error in browser console | Rasa started without `--cors` | Restart Step 4 with `--cors "*"` |
| `pip install` resolver errors | Python 3.11+ | Rebuild the venv on 3.10 |
| Assessment returns nothing useful | Dataset failed to load | Check the `Knowledge base loaded:` counts in Step 3 |
| Hospital list always empty | No `PLACES_API_KEY`, or location denied | See [Optional](#optional-hospital-search) |

---

## Running the tests instead

Neither suite needs a running server:

```powershell
cd backend
pip install -r requirements-dev.txt
pytest

cd health_bot_app
flutter test
flutter analyze
```

End-to-end tests against a live server are opt-in, and need Steps 3–4 running:

```powershell
$env:HEALTHBOT_LIVE_URL = "http://localhost:5005"
pytest tests/test_live_server.py
```

---

## Docker alternative

To skip Steps 1–4 entirely — this builds both backend containers with the
model baked in, and needs no local Python:

```bash
cp .env.example .env      # set RASA_AUTH_TOKEN
docker compose up --build
```

The app still runs from Step 5, but `RASA_AUTH_TOKEN` in `env.json` must then
match the one in `.env` — the containerised server refuses to start without a
token and rejects requests that omit it. (`RASA_ALLOW_UNAUTHENTICATED=true`
bypasses that check; it exists for throwaway local runs, not for anything
reachable off your machine.)
