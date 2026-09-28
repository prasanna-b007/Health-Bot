# Deployment

Two deliverables: a containerised backend (Rasa server + action server) and a
signed Android app that talks to it.

---

## Before you start

These need a human decision or a credential this repository cannot contain.

| # | Item | Why |
|---|---|---|
| 1 | **Rotate the Geoapify API key** | The old key was committed and is still readable in git history. Removing the line did not revoke it. |
| 2 | **Confirm the application ID** | Set to `com.sustainworld.healthbot`. It is permanent once published to Play Store — change it now if that is wrong. |
| 3 | **Create an upload keystore** | Release builds were signed with the *debug* key, which Play Store rejects. See [Signing](#signing). |
| 4 | **Provision a domain and TLS certificate** | The app refuses to run a release build against `http://`. |
| 5 | **Generate `RASA_AUTH_TOKEN`** | The backend will not start without one unless you opt out explicitly. |

---

## Backend

### Layout

Two images, deliberately separated:

| Service | Image | Contains | Size |
|---|---|---|---|
| `rasa` | `backend/Dockerfile` | Rasa + TensorFlow + the trained model | ~2 GB |
| `actions` | `backend/Dockerfile.actions` | `rasa-sdk` + the triage engine | ~300 MB |

The triage engine imports no Rasa, so the action server image skips the
TensorFlow stack entirely. Only the `rasa` service needs rebuilding when
training data changes; only `actions` needs it when triage logic changes.

The model is trained **during the image build** with `--fixed-model-name`, so
an image is a self-contained artefact — the same tag always serves the same
model, with no train-on-boot delay and no shared volume to keep in sync.

### Run it

```bash
cp .env.example .env
# Generate a token and put it in .env
openssl rand -hex 32

docker compose up --build
```

The first build installs TensorFlow and trains the model; expect several
minutes. Later builds reuse cached layers unless `data/`, `config.yml` or
`domain.yml` change.

Verify:

```bash
curl -fsS http://localhost:5005/                      # unauthenticated probe
curl -fsS -X POST "http://localhost:5005/webhooks/rest/webhook?token=$RASA_AUTH_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"sender":"smoke","message":"I have fever and headache","metadata":{"age":30,"duration":3,"severity":5}}'
```

### Security posture

What the compose file does, and why:

- **The API binds to `127.0.0.1`.** Publishing it directly would expose an
  unencrypted health endpoint. Put a TLS-terminating reverse proxy in front
  and leave the container on loopback.
- **`RASA_AUTH_TOKEN` is mandatory.** The entrypoint exits with an explanation
  if it is unset, rather than starting wide open. `RASA_ALLOW_UNAUTHENTICATED=true`
  overrides this for a trusted network — an explicit choice, not a default.
- **CORS is empty by default.** Native mobile clients send no `Origin` header
  and need no CORS. The development `--cors "*"` is not baked into the image.
- **The action server is not published.** It is reachable only over the
  internal compose network; nothing outside needs it.
- **Both containers run as non-root** (uid 10001).
- **`credentials.docker.yml` is REST-only.** The development `credentials.yml`
  also lists a `rasa:` Enterprise endpoint at `localhost:5002`, which does not
  exist in this deployment and produces connection errors on every start.

Understand the limit of the token: it is a *shared* secret compiled into the
app binary, so anyone who extracts it can call the API. It stops an open port
being driven by whoever finds it; it does not authenticate a user. Per-user
auth requires a backend that issues credentials, which this project does not
have.

### Reverse proxy

Minimal nginx in front of the compose stack:

```nginx
server {
    listen 443 ssl http2;
    server_name api.your-domain.example;

    ssl_certificate     /etc/letsencrypt/live/api.your-domain.example/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.your-domain.example/privkey.pem;

    # Triage turns are short; the default 60s read timeout is ample.
    location /webhooks/ {
        proxy_pass http://127.0.0.1:5005;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Everything else on the Rasa API — /model, /conversations, /status — is
    # administrative. Do not expose it.
    location / { return 404; }
}
```

That last block matters. Rasa's API includes endpoints that can replace the
model and read conversation transcripts. Only `/webhooks/` should be reachable.

### Updating

```bash
git pull
docker compose build
docker compose up -d
```

Because the model is baked in, a rollback is `IMAGE_TAG=<previous> docker compose up -d`.

---

## Android app

### Signing

Generate an upload keystore once. **Keep it and its passwords safe — losing it
means you can never ship an update to the same Play Store listing.**

```bash
keytool -genkey -v -keystore ~/healthbot-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

```bash
cd health_bot_app/android
cp key.properties.example key.properties
# fill in storePassword, keyPassword, keyAlias, storeFile
```

`key.properties`, `*.jks` and `*.keystore` are gitignored.

If `key.properties` is absent the release build falls back to the debug key so
`flutter run --release` still works locally, and Gradle prints a warning. An
artefact produced that way is not publishable; the CI release job fails if it
detects one.

### Build

```bash
cd health_bot_app
cp env.example.json env.json     # gitignored
```

```json
{
  "RASA_BASE_URL": "https://api.your-domain.example",
  "RASA_AUTH_TOKEN": "the same token as the backend .env",
  "PLACES_API_KEY": "your rotated Geoapify key",
  "HOSPITAL_SEARCH_RADIUS_M": 5000
}
```

```bash
flutter build appbundle --release --dart-define-from-file=env.json   # Play Store
flutter build apk --release --dart-define-from-file=env.json         # direct install
```

A release build **throws at startup** if `RASA_BASE_URL` uses `http://`, still
points at a development machine, or the auth token is missing. That is
deliberate: shipping symptom data over cleartext is a packaging mistake worth
catching on your own device rather than in the wild.

### What changed for release

- **Application ID** — was `com.example.health_bot_app`, which Play Store rejects.
- **Launcher label** — was `health_bot_app`, the raw Flutter project name.
- **Signing** — was the debug key.
- **Cleartext traffic** — the manifest set `usesCleartextTraffic="true"`,
  permitting plain HTTP to any host. Release builds now enforce TLS via
  `network_security_config.xml`; the debug source set overrides it to allow
  HTTP to `10.0.2.2`, `localhost` and private LAN ranges.
- **Minification** — R8 with `shrinkResources` is on, and `android.util.Log`
  d/v/i calls are stripped so request detail does not reach a shipped device log.
- **Backup** — `allowBackup="false"` plus data-extraction rules. Symptom
  assessments are health information and should not sync to cloud backup.
- **Location** — coarse location is enough to rank hospitals by distance, and
  the location hardware features are marked `required="false"` so the app
  still installs on devices without GPS.

---

## Verifying a deployment

```bash
# Backend, no server needed — 162 tests
cd backend && pytest

# Backend, against the running stack
HEALTHBOT_LIVE_URL=http://localhost:5005 pytest tests/test_live_server.py

# App — 69 tests
cd health_bot_app && flutter analyze && flutter test
```

The live suite covers the paths that matter most: an emergency phrase
escalates, an emergency mid-conversation escalates, the escalation does not
repeat on the following turn, and a full assessment reaches a result.

Against a stack started with an auth token, pass it too:

```bash
HEALTHBOT_LIVE_URL=http://localhost:5005 HEALTHBOT_AUTH_TOKEN="$RASA_AUTH_TOKEN"   pytest tests/test_live_server.py
```

---

## Not done

Honest list of what this setup does not cover.

- **No persistent tracker store.** Rasa defaults to in-memory, so conversation
  state is lost on restart and cannot be shared across replicas. Running more
  than one `rasa` container requires configuring Redis or Postgres in
  `endpoints.docker.yml` first.
- **No monitoring or alerting.** Health checks exist; nothing scrapes them.
- **No log aggregation.** Logs go to the container stdout and stay there.
- **No iOS build configuration.** Only Android is release-ready.
- **No rate limiting.** Add it at the reverse proxy.
- **Git history still contains the leaked API key** (and ~640 build artefacts,
  which is why `.git` is ~768 MB). Rotating the key addresses the exposure;
  `git filter-repo` would remove it from history, at the cost of rewriting
  history for every clone.
