"""End-to-end checks against a running Rasa server.

Opt-in: these are skipped unless HEALTHBOT_LIVE_URL is set, because they need
`rasa run --enable-api` and `rasa run actions` up. Everything else in this
directory runs with no server at all.

    rasa run actions
    rasa run --enable-api --cors "*" --port 5005
    HEALTHBOT_LIVE_URL=http://localhost:5005 pytest tests/test_live_server.py

Against a deployment started with --auth-token, also set
HEALTHBOT_AUTH_TOKEN; it is sent as the `token` query parameter Rasa checks.

This replaces test_regression.py, which printed transcripts for a human to
read and asserted nothing -- so it could not fail, and never ran in CI.
"""
import os
import uuid

import pytest

requests = pytest.importorskip("requests")

LIVE_URL = os.environ.get("HEALTHBOT_LIVE_URL")
AUTH_TOKEN = os.environ.get("HEALTHBOT_AUTH_TOKEN")

pytestmark = pytest.mark.skipif(
    not LIVE_URL, reason="set HEALTHBOT_LIVE_URL to run live server tests"
)


def send(message, sender=None, metadata=None, timeout=30):
    payload = {"sender": sender or "test_{}".format(uuid.uuid4().hex[:8]), "message": message}
    if metadata:
        payload["metadata"] = metadata
    params = {"token": AUTH_TOKEN} if AUTH_TOKEN else None
    response = requests.post(
        "{}/webhooks/rest/webhook".format(LIVE_URL),
        json=payload,
        params=params,
        timeout=timeout,
    )
    if response.status_code in (401, 403):
        pytest.fail(
            "Server rejected the request ({}). Set HEALTHBOT_AUTH_TOKEN to the "
            "token the server was started with.".format(response.status_code)
        )
    response.raise_for_status()
    return response.json()


def payloads(responses, kind):
    return [r["custom"] for r in responses
            if isinstance(r.get("custom"), dict) and r["custom"].get("type") == kind]


class TestEmergencyPath:
    def test_chest_pain_escalates_immediately(self):
        responses = send("I have severe chest pain and I cannot breathe")
        assert payloads(responses, "emergency"), responses

    def test_apostrophe_phrasing_escalates(self):
        responses = send("chest pain and I can't breathe")
        assert payloads(responses, "emergency"), responses

    def test_emergency_mid_conversation(self):
        sender = "test_mid_{}".format(uuid.uuid4().hex[:8])
        send("I have a mild fever", sender=sender, metadata={"age": 30, "duration": 2, "severity": 4})
        responses = send("I am having a heart attack", sender=sender)
        assert payloads(responses, "emergency"), responses

    def test_emergency_does_not_repeat_on_the_next_turn(self):
        """emergency_detected used to stay true and re-trigger every turn."""
        sender = "test_sticky_{}".format(uuid.uuid4().hex[:8])
        send("I have chest pain", sender=sender)
        responses = send("hello", sender=sender)
        assert not payloads(responses, "emergency"), responses


class TestTriagePath:
    def test_metadata_skips_the_intake_questions(self):
        responses = send(
            "I have fever and headache",
            metadata={"age": 22, "duration": 5, "severity": 8},
        )
        questions = payloads(responses, "question")
        assert questions, responses
        assert questions[0]["input_type"] == "yes_no"

    def test_intake_is_requested_without_metadata(self):
        responses = send("I have fever and headache")
        questions = payloads(responses, "question")
        assert questions and questions[0]["input_type"] == "number"

    def test_a_full_conversation_reaches_a_result(self):
        sender = "test_full_{}".format(uuid.uuid4().hex[:8])
        responses = send(
            "I have itching and skin rash",
            sender=sender,
            metadata={"age": 30, "duration": 3, "severity": 5},
        )
        for _ in range(triage_turns := 8):
            results = payloads(responses, "result")
            if results:
                result = results[0]
                assert "confidence_band" in result
                assert result["disclaimer"]
                return
            assert payloads(responses, "question"), responses
            responses = send("yes", sender=sender)
        pytest.fail("no result after {} turns".format(triage_turns))

    def test_unrecognised_input_asks_for_a_rephrase(self):
        responses = send("blah blah blah", metadata={"age": 30, "duration": 1, "severity": 1})
        assert responses, "server returned nothing"
