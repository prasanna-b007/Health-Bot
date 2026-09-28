"""A stateless HTTP front end for the triage engine.

Rasa is used in this project as an intent router and nothing more: every rule
in data/rules.yml maps one intent straight to one custom action, all thirteen
intents are yes / no / symptom text / small talk, and every decision lives in
actions/, which imports no Rasa at all. What that routing costs is the whole
TensorFlow stack, a hard Python <= 3.10 pin, several hundred megabytes of
model artefacts, a ninety-second healthcheck start period, and a retrain on
every domain.yml edit.

This module is the same engine behind about two hundred lines of FastAPI. It
is deliberately *additive*: the Rasa server and action server still work
unchanged, and nothing here imports them. Run whichever suits the deployment,
or run both while migrating. What this one buys:

* **No tracker store.** Conversation state is signed and handed to the client
  (see state.py), so the service scales horizontally with nothing shared, and
  the server never retains anyone's symptoms.
* **Rate limiting**, which the Rasa port has none of.
* **A versioned contract.** The payload shape the app depends on becomes an
  explicit schema instead of whatever `json_message` happened to contain.
* **Seconds to start**, and a container measured in tens of megabytes.

Install with `pip install -r requirements-api.txt`, run with
`uvicorn api.main:app --port 8000`.
"""
import logging
import os
import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from typing import Any, Deque, Dict, List, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from actions import prevalence, triage
from actions.datastore import DatasetError, load

from . import state as session_state

logger = logging.getLogger(__name__)

API_VERSION = "1"

# Shared secret, checked as a bearer token or a `token` query parameter so the
# existing app can point at this service with the same configuration it uses
# for Rasa. Absent means open, which is refused at startup unless explicitly
# allowed -- the same bargain docker-entrypoint.sh strikes for Rasa.
ENV_TOKEN = "HEALTHBOT_API_TOKEN"
ENV_ALLOW_OPEN = "HEALTHBOT_ALLOW_UNAUTHENTICATED"
ENV_CORS = "HEALTHBOT_CORS"

# Rate limit per client, per window. Generous for a human working through an
# assessment (one request per answer) and restrictive for anything enumerating
# the engine. The Rasa deployment has no equivalent: an open port plus a token
# extractable from any APK is free compute.
RATE_LIMIT_REQUESTS = int(os.environ.get("HEALTHBOT_RATE_LIMIT", "60"))
RATE_LIMIT_WINDOW_SECONDS = 60

MAX_MESSAGE_LENGTH = 2000


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------
class TriageRequest(BaseModel):
    message: str = Field(default="", max_length=MAX_MESSAGE_LENGTH)
    # Opaque. The client stores it and sends back whatever it last received.
    session: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class TriageReply(BaseModel):
    messages: List[Dict[str, Any]]
    session: Optional[str]
    finished: bool


# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
KB = None
_requests: Dict[str, Deque[float]] = defaultdict(deque)


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Load and check everything at boot, so a broken deployment fails here.

    The knowledge base is validated, and an unauthenticated configuration is
    refused unless it was asked for explicitly -- the same bargain
    docker-entrypoint.sh strikes for the Rasa server. Both of these used to be
    discovered at the first user message instead.
    """
    global KB
    try:
        KB = load()
    except DatasetError:
        logger.exception("Knowledge base failed to load; refusing to start")
        raise

    if not os.environ.get(ENV_TOKEN):
        if os.environ.get(ENV_ALLOW_OPEN, "").lower() != "true":
            raise RuntimeError(
                "{0} is not set. Set it, or set {1}=true to run without "
                "authentication on a trusted network.".format(
                    ENV_TOKEN, ENV_ALLOW_OPEN
                )
            )
        logger.warning("Running without authentication (%s=true)", ENV_ALLOW_OPEN)

    logger.info(
        "Triage API ready: %d conditions, region %r",
        len(KB.disease_symptoms), prevalence.configured_region(),
    )
    yield


app = FastAPI(
    title="Health-Bot triage API",
    version=API_VERSION,
    description="Stateless triage over the same engine the action server uses.",
    lifespan=lifespan,
)

_origins = [o.strip() for o in os.environ.get(ENV_CORS, "").split(",") if o.strip()]
if _origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_origins,
        allow_methods=["POST", "GET"],
        allow_headers=["*"],
    )


def _client_key(request: Request) -> str:
    """Who to rate limit.

    Behind the reverse proxy DEPLOYMENT.md describes, the peer address is the
    proxy, so the forwarded header is used when present. That header is
    client-controlled and trivially spoofed, which is acceptable here: this
    limit exists to stop casual hammering, and anything stronger belongs in
    the proxy where the real address is known.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def rate_limit(request: Request) -> None:
    now = time.monotonic()
    key = _client_key(request)
    window = _requests[key]
    cutoff = now - RATE_LIMIT_WINDOW_SECONDS
    while window and window[0] < cutoff:
        window.popleft()
    if len(window) >= RATE_LIMIT_REQUESTS:
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please slow down.",
            headers={"Retry-After": str(RATE_LIMIT_WINDOW_SECONDS)},
        )
    window.append(now)

    # Keep the table from growing without bound on a long-lived process.
    if len(_requests) > 10000:
        for stale in [k for k, v in _requests.items() if not v]:
            del _requests[stale]


def authorize(
    request: Request, authorization: Optional[str] = Header(default=None)
) -> None:
    expected = os.environ.get(ENV_TOKEN)
    if not expected:
        return
    supplied = request.query_params.get("token")
    if authorization and authorization.lower().startswith("bearer "):
        supplied = authorization[7:].strip()
    if supplied != expected:
        raise HTTPException(status_code=401, detail="Not authorised.")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/health")
def health() -> Dict[str, Any]:
    """Liveness plus enough detail to tell two deployments apart."""
    return {
        "status": "ok" if KB else "starting",
        "api_version": API_VERSION,
        "conditions": len(KB.disease_symptoms) if KB else 0,
        "region": prevalence.configured_region(),
    }


@app.post(
    "/v1/triage",
    response_model=TriageReply,
    dependencies=[Depends(rate_limit), Depends(authorize)],
)
def post_triage(body: TriageRequest) -> TriageReply:
    """One conversational turn.

    The client sends the message and whatever `session` it last received; it
    gets back the engine's messages and a new `session` to send next time. A
    missing or unverifiable session simply starts a fresh assessment.
    """
    if KB is None:
        raise HTTPException(status_code=503, detail="Knowledge base not loaded.")

    try:
        current = session_state.load(body.session)
    except session_state.StateError as exc:
        # Tampered or corrupt. Start over rather than arguing about it -- and
        # never echo the offending token back in the error.
        logger.info("Discarding an unusable session token: %s", exc)
        current = None

    current = current or triage.TriageState()
    text = (body.message or "").strip()
    session_state.metadata_into(current, body.metadata)

    # Red flags come first, before anything else looks at the text, exactly as
    # in the Rasa adapter.
    flag = triage.classify_red_flag(text, current)
    if flag is not None:
        outcome = triage.red_flag_outcome(flag)
        return _reply(outcome, finished=True)

    outcome = _advance(current, text)

    # Confirming a symptom can itself be a red flag.
    if outcome.state is not None:
        flag = triage.classify_red_flag(None, outcome.state)
        if flag is not None:
            return _reply(triage.red_flag_outcome(flag), finished=True)

    return _reply(outcome)


def _advance(current: triage.TriageState, text: str) -> triage.Outcome:
    """Route one message: an answer to a pending question, or new symptoms."""
    lowered = text.lower()

    if current.pending and lowered in _YES:
        current.confirm(current.pending)
        current.pending = None
        return triage.advance(KB, current)
    if current.pending and lowered in _NO:
        current.deny(current.pending)
        current.pending = None
        return triage.advance(KB, current)
    if current.pending and lowered in _UNSURE:
        current.mark_unknown(current.pending)
        current.pending = None
        return triage.advance(KB, current)

    # A number answering one of the intake questions.
    attribute = {
        triage.STAGE_AGE: "age",
        triage.STAGE_DURATION: "duration_days",
        triage.STAGE_SEVERITY: "severity",
    }.get(current.stage)
    if attribute is not None:
        from actions.text_utils import parse_number

        value = parse_number(text)
        if value is None:
            return triage.Outcome(
                messages=[triage.BotMessage(
                    text="Sorry, I need a number for that. Could you try again?",
                    payload={"type": "question", "input_type": "number"},
                )],
                state=current,
            )
        problem = triage.validate_intake(attribute, value)
        if problem is not None:
            return triage.Outcome(
                messages=[triage.BotMessage(
                    text=problem,
                    payload={"type": "question", "question": problem,
                             "question_text": problem, "input_type": "number"},
                )],
                state=current,
            )
        setattr(current, attribute, value)
        return triage.advance(KB, current)

    return triage.start(KB, text, current)


_YES = {"yes", "y", "yeah", "yep", "yup", "sure", "correct", "true", "1"}
_NO = {"no", "n", "nope", "nah", "negative", "false", "0"}
_UNSURE = {"unsure", "not sure", "i'm not sure", "im not sure", "maybe",
           "dont know", "don't know", "idk"}


def _reply(outcome: triage.Outcome, finished: Optional[bool] = None) -> TriageReply:
    messages = [
        {"text": message.text, "custom": message.payload}
        for message in outcome.messages
    ]
    done = outcome.finished if finished is None else finished
    # A finished assessment hands back no session: there is nothing to carry
    # forward, and returning one would invite a client to keep answering
    # questions about an assessment that is over.
    token = None if done or outcome.state is None else session_state.dump(outcome.state)
    return TriageReply(messages=messages, session=token, finished=done)


@app.exception_handler(HTTPException)
def _http_error(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.detail},
        headers=getattr(exc, "headers", None),
    )
