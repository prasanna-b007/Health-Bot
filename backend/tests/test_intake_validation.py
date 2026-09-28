"""Plausibility checks on user-supplied intake values.

Age, duration and severity each move the risk score on their own, so a typo or
a bad client changes the advice a user is given. The app validates before
sending; these cover the server refusing to take the numbers on trust.
"""
import pytest

from actions import triage
from actions.config import THRESHOLDS


class TestValidateIntake:
    @pytest.mark.parametrize("value", [0, 1, 34, 65, 120])
    def test_plausible_ages_are_accepted(self, value):
        assert triage.validate_intake("age", value) is None

    @pytest.mark.parametrize("value", [-1, 121, 999, 10000])
    def test_implausible_ages_are_rejected(self, value):
        assert triage.validate_intake("age", value) is not None

    def test_age_bounds_come_from_config(self):
        assert triage.validate_intake("age", THRESHOLDS["AGE_MIN"]) is None
        assert triage.validate_intake("age", THRESHOLDS["AGE_MAX"]) is None
        assert triage.validate_intake("age", THRESHOLDS["AGE_MAX"] + 1) is not None

    @pytest.mark.parametrize("value", [1, 5, 10])
    def test_plausible_severity_is_accepted(self, value):
        assert triage.validate_intake("severity", value) is None

    @pytest.mark.parametrize("value", [0, 11, -3, 100])
    def test_implausible_severity_is_rejected(self, value):
        assert triage.validate_intake("severity", value) is not None

    @pytest.mark.parametrize("value", [0, 1, 14, 3650])
    def test_plausible_durations_are_accepted(self, value):
        assert triage.validate_intake("duration_days", value) is None

    @pytest.mark.parametrize("value", [-1, 3651])
    def test_implausible_durations_are_rejected(self, value):
        assert triage.validate_intake("duration_days", value) is not None

    def test_missing_values_are_not_errors(self):
        # None means "not answered yet", which the intake flow handles.
        assert triage.validate_intake("age", None) is None

    def test_unknown_attribute_is_ignored(self):
        assert triage.validate_intake("shoe_size", 45) is None

    def test_messages_state_the_acceptable_range(self):
        message = triage.validate_intake("age", 999)
        assert str(THRESHOLDS["AGE_MAX"]) in message
        assert str(THRESHOLDS["AGE_MIN"]) in message


class TestSanitizeIntake:
    def test_implausible_metadata_is_discarded(self):
        state = triage.TriageState(age=999, duration_days=4, severity=6)
        dropped = triage.sanitize_intake(state)
        assert dropped == ["age"]
        assert state.age is None
        # Valid neighbours are left alone.
        assert state.duration_days == 4
        assert state.severity == 6

    def test_plausible_metadata_survives(self):
        state = triage.TriageState(age=34, duration_days=4, severity=6)
        assert triage.sanitize_intake(state) == []
        assert state.age == 34

    def test_several_bad_values_are_all_dropped(self):
        state = triage.TriageState(age=-4, duration_days=99999, severity=50)
        dropped = triage.sanitize_intake(state)
        assert set(dropped) == {"age", "duration_days", "severity"}
        assert (state.age, state.duration_days, state.severity) == (None, None, None)

    def test_discarded_values_are_asked_for_again(self, kb):
        """Dropping a value must re-enter the intake flow, not skip it."""
        state = triage.TriageState(age=999, duration_days=4, severity=6)
        triage.sanitize_intake(state)
        outcome = triage.advance(kb, state)
        assert outcome.state.stage == triage.STAGE_AGE

    def test_a_bad_age_cannot_reach_risk_scoring(self, kb):
        state = triage.TriageState(age=999, duration_days=4, severity=6)
        state.confirmed = ["itching", "skin rash"]
        triage.sanitize_intake(state)
        assert state.age is None
        # calculate_risk substitutes its own default for a missing age rather
        # than scoring against an implausible one.
        risk = triage.calculate_risk(state.age, 4, 6, 2)
        assert "Age-related vulnerability" not in risk.factors
        assert "Infant vulnerability" not in risk.factors
