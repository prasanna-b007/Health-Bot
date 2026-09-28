"""Conversation state that travels with the client, signed.

Rasa keeps triage state in a tracker store, and this deployment configures
none -- so it defaults to the in-memory one. Two consequences follow, and both
are the kind that only show up in production: restarting the server loses
every assessment in flight, and running a second replica breaks triage
outright, because turn two round-robins to a process that never saw turn one.

The fix here is not a bigger store. It is to stop the server holding the
conversation at all. The whole TriageState is a small flat dataclass, so it
can go back to the client with each reply and return with the next request.
That makes the API horizontally scalable with no shared store, survivable
across restarts and deploys, and -- the part that matters most for this
application -- it means the server never retains anyone's symptoms. There is
nothing to leak, subpoena or forget to delete.

The state is signed, not encrypted. It is the user's own data and they may
read it; what signing prevents is a *modified* state coming back, which would
let anyone hand the engine arbitrary confirmed symptoms, drive the risk score
from outside, or use a tampered blob to probe for parser bugs. An invalid
signature is treated as no state at all: the assessment restarts, which is
annoying but never wrong.
"""
import base64
import hashlib
import hmac
import json
import logging
import os
import time
from typing import Any, Dict, Optional

from actions import triage

logger = logging.getLogger(__name__)

# Secret used to sign state blobs. Generated per process when unset, which is
# fine for a single instance and wrong for several -- a state signed by one
# replica would be rejected by the next. Multi-replica deployments must set
# it, and the startup check in main.py says so loudly.
ENV_SECRET = "HEALTHBOT_STATE_SECRET"

# How long a signed state stays valid. Long enough that nobody is timed out
# mid-assessment while looking up their age; short enough that a blob copied
# out of a log is not useful a week later.
MAX_AGE_SECONDS = 60 * 60 * 6

_VERSION = "1"


class StateError(ValueError):
    """The client sent a state we will not accept."""


def _secret() -> bytes:
    configured = os.environ.get(ENV_SECRET)
    if configured:
        return configured.encode("utf-8")
    global _EPHEMERAL
    if _EPHEMERAL is None:
        _EPHEMERAL = os.urandom(32)
        logger.warning(
            "%s is not set; signing state with a per-process key. Sessions "
            "will not survive a restart and MUST NOT be load balanced across "
            "more than one instance.", ENV_SECRET,
        )
    return _EPHEMERAL


_EPHEMERAL: Optional[bytes] = None


def _sign(payload: bytes) -> str:
    digest = hmac.new(_secret(), payload, hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def _b64encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64decode(text: str) -> bytes:
    padding = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + padding)


def dump(state: triage.TriageState) -> str:
    """Serialise and sign a state for the client to hold."""
    body = {
        "v": _VERSION,
        "t": int(time.time()),
        "confirmed": state.confirmed,
        "denied": state.denied,
        "unknown": state.unknown,
        "asked": state.asked,
        "pending": state.pending,
        "question_count": state.question_count,
        "age": state.age,
        "duration_days": state.duration_days,
        "severity": state.severity,
        "stage": state.stage,
        "conditions": state.conditions,
    }
    raw = json.dumps(body, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return "{}.{}".format(_b64encode(raw), _sign(raw))


def load(token: Optional[str]) -> Optional[triage.TriageState]:
    """Verify and rebuild a state, or None when there is not a usable one.

    Raises StateError only for a token that is present and *wrong*, so the
    caller can tell "new conversation" apart from "something tampered".
    """
    if not token:
        return None
    try:
        encoded, signature = token.rsplit(".", 1)
        raw = _b64decode(encoded)
    except (ValueError, TypeError) as exc:
        raise StateError("malformed session token") from exc

    if not hmac.compare_digest(signature, _sign(raw)):
        raise StateError("session token failed verification")

    try:
        body = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError) as exc:
        raise StateError("unreadable session token") from exc

    if body.get("v") != _VERSION:
        # A deploy changed the shape. Starting over beats guessing.
        return None
    issued = body.get("t")
    if not isinstance(issued, int) or time.time() - issued > MAX_AGE_SECONDS:
        return None

    state = triage.TriageState(
        confirmed=_strings(body.get("confirmed")),
        denied=_strings(body.get("denied")),
        unknown=_strings(body.get("unknown")),
        asked=_strings(body.get("asked")),
        pending=_optional_string(body.get("pending")),
        question_count=_bounded_int(body.get("question_count"), 0, 50) or 0,
        age=_bounded_int(body.get("age"), 0, 120),
        duration_days=_bounded_int(body.get("duration_days"), 0, 3650),
        severity=_bounded_int(body.get("severity"), 1, 10),
        stage=_optional_string(body.get("stage")),
        conditions=_strings(body.get("conditions"), limit=20, length=80),
    )
    # Signed or not, the engine's own plausibility rules still run. A valid
    # signature proves the blob came from us, not that it is sane -- and this
    # process may be running a build whose bounds have since tightened.
    triage.sanitize_intake(state)
    return state


def _strings(value: Any, limit: int = 100, length: int = 120) -> list:
    if not isinstance(value, list):
        return []
    out = []
    for item in value:
        if isinstance(item, str) and item.strip():
            out.append(item.strip()[:length])
        if len(out) >= limit:
            break
    return out


def _optional_string(value: Any, length: int = 120) -> Optional[str]:
    if isinstance(value, str) and value.strip():
        return value.strip()[:length]
    return None


def _bounded_int(value: Any, low: int, high: int) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, int):
        return None
    return value if low <= value <= high else None


def metadata_into(state: triage.TriageState, metadata: Optional[Dict[str, Any]]) -> None:
    """Adopt intake values and profile conditions sent with a message.

    Mirrors actions.apply_metadata; kept separate because that one reaches
    into a Rasa tracker and this one does not.
    """
    if not isinstance(metadata, dict):
        return
    for key, attribute in (("age", "age"), ("duration", "duration_days"),
                           ("severity", "severity")):
        value = metadata.get(key)
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)):
            setattr(state, attribute, int(value))
    conditions = _strings(metadata.get("conditions"), limit=20, length=80)
    if conditions:
        state.conditions = conditions
    triage.sanitize_intake(state)
