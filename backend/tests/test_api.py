"""The stateless triage API.

Skipped unless FastAPI is installed, because the engine test suite runs
without it on purpose -- pydantic 2 and rasa 3.6 cannot share a virtualenv,
so the two servers are tested in separate environments. See requirements-api.txt.

What these cover is the part that is genuinely new rather than a re-test of
the engine: that a conversation survives entirely in the client's hands, that
a tampered state cannot drive the engine, and that red flags short-circuit
before anything else runs.
"""
import pytest

fastapi = pytest.importorskip("fastapi", reason="pip install -r requirements-api.txt")
from fastapi.testclient import TestClient  # noqa: E402

from actions import triage  # noqa: E402
from api import state as session_state  # noqa: E402


@pytest.fixture(scope="module")
def client(monkeypatch_module=None):
    import os

    os.environ["HEALTHBOT_ALLOW_UNAUTHENTICATED"] = "true"
    os.environ.pop("HEALTHBOT_API_TOKEN", None)
    os.environ["HEALTHBOT_STATE_SECRET"] = "test-secret-not-for-production"
    from api.main import app

    with TestClient(app) as test_client:
        yield test_client


def triage_post(client, message, session=None, metadata=None):
    body = {"message": message}
    if session:
        body["session"] = session
    if metadata:
        body["metadata"] = metadata
    response = client.post("/v1/triage", json=body)
    assert response.status_code == 200, response.text
    return response.json()


class TestHealth:
    def test_reports_ready(self, client):
        payload = client.get("/health").json()
        assert payload["status"] == "ok"
        assert payload["conditions"] == 41


class TestConversation:
    def test_an_assessment_runs_to_a_result(self, client):
        reply = triage_post(
            client,
            "high fever with chills and a terrible headache",
            metadata={"age": 28, "duration": 4, "severity": 8},
        )
        turns = 0
        while not reply["finished"] and turns < 10:
            assert reply["session"], "an unfinished turn must return a session"
            reply = triage_post(client, "yes", session=reply["session"])
            turns += 1
        assert reply["finished"]
        result = reply["messages"][0]["custom"]
        assert result["type"] == "result"
        assert result["disposition"] in triage.DISPOSITIONS

    def test_state_lives_entirely_in_the_client(self, client):
        """No tracker store, so two turns need share nothing but the token."""
        first = triage_post(
            client, "I have a headache and a fever",
            metadata={"age": 30, "duration": 2, "severity": 5},
        )
        token = first["session"]
        # The same token replayed twice must behave identically: the server
        # is holding nothing that the second call could disturb.
        a = triage_post(client, "yes", session=token)
        b = triage_post(client, "yes", session=token)
        assert a["messages"][0]["text"] == b["messages"][0]["text"]

    def test_a_finished_assessment_returns_no_session(self, client):
        reply = triage_post(client, "i cant breathe")
        assert reply["finished"]
        assert reply["session"] is None

    def test_an_absent_session_starts_over(self, client):
        reply = triage_post(client, "I have a headache",
                            metadata={"age": 30, "duration": 1, "severity": 4})
        assert reply["messages"]


class TestRedFlags:
    def test_an_emergency_short_circuits(self, client):
        reply = triage_post(client, "I have crushing chest pain")
        custom = reply["messages"][0]["custom"]
        assert custom["emergency"] is True
        assert custom["category"] == "emergency"
        assert reply["finished"]

    def test_a_crisis_routes_separately(self, client):
        reply = triage_post(client, "I want to end my life")
        custom = reply["messages"][0]["custom"]
        assert custom["category"] == "crisis"
        assert custom["reason"] is None

    def test_a_negated_red_flag_does_not_escalate(self, client):
        reply = triage_post(
            client, "no chest pain, just a headache",
            metadata={"age": 30, "duration": 2, "severity": 4},
        )
        custom = reply["messages"][0]["custom"] or {}
        assert custom.get("emergency") is not True


class TestSignedState:
    def test_a_round_trip_preserves_the_state(self):
        original = triage.TriageState(
            confirmed=["high fever"], denied=["cough"], age=40,
            duration_days=3, severity=6, question_count=2, pending="chills",
        )
        restored = session_state.load(session_state.dump(original))
        assert restored.confirmed == ["high fever"]
        assert restored.denied == ["cough"]
        assert restored.age == 40
        assert restored.pending == "chills"

    def test_a_tampered_state_is_rejected(self):
        token = session_state.dump(triage.TriageState(confirmed=["cough"]))
        body, signature = token.rsplit(".", 1)
        forged = session_state.dump(
            triage.TriageState(confirmed=["chest pain"])
        ).rsplit(".", 1)[0]
        with pytest.raises(session_state.StateError):
            session_state.load("{}.{}".format(forged, signature))

    def test_garbage_is_rejected_rather_than_parsed(self):
        with pytest.raises(session_state.StateError):
            session_state.load("not-a-token")

    def test_no_token_is_not_an_error(self):
        assert session_state.load(None) is None
        assert session_state.load("") is None

    def test_implausible_values_are_dropped_even_when_signed(self):
        """A valid signature proves origin, not sanity."""
        state = triage.TriageState(age=30)
        token = session_state.dump(state)
        restored = session_state.load(token)
        assert restored.age == 30
        # Bounds are re-applied on load, so a build that tightens them is not
        # bypassed by a token signed by an older one.
        loose = triage.TriageState(age=200)
        assert session_state.load(session_state.dump(loose)).age is None

    def test_a_tampered_session_restarts_rather_than_failing(self, client):
        reply = triage_post(client, "I have a headache", session="garbage.token")
        assert reply["messages"]


class TestRateLimit:
    def test_the_limit_eventually_refuses(self, client):
        from api import main

        original = main.RATE_LIMIT_REQUESTS
        main.RATE_LIMIT_REQUESTS = 3
        main._requests.clear()
        try:
            statuses = [
                client.post("/v1/triage", json={"message": "hello"}).status_code
                for _ in range(6)
            ]
            assert 429 in statuses
        finally:
            main.RATE_LIMIT_REQUESTS = original
            main._requests.clear()


class TestValidation:
    def test_an_overlong_message_is_refused(self, client):
        response = client.post("/v1/triage", json={"message": "a" * 5000})
        assert response.status_code == 422

    def test_metadata_out_of_range_is_discarded(self, client):
        reply = triage_post(
            client, "I have a headache",
            metadata={"age": 999, "duration": 2, "severity": 5},
        )
        # 999 must not drive the assessment; the engine asks for a real age.
        custom = reply["messages"][0]["custom"] or {}
        assert custom.get("input_type") == "number"
