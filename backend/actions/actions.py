"""Rasa action server: a thin adapter over the triage engine.

This module deliberately contains no triage logic. Its whole job is to move
values between Rasa slots and triage.TriageState, hand off to the engine, and
translate the engine's messages back into dispatcher calls. The decision
making lives in triage.py, scoring.py and emergency.py, none of which import
Rasa -- which is what makes them testable without an action server.
"""
import logging
from typing import Any, Dict, List, Optional, Text

# pyrefly: ignore [missing-import]
from rasa_sdk import Action, Tracker
# pyrefly: ignore [missing-import]
from rasa_sdk.events import FollowupAction, SlotSet
# pyrefly: ignore [missing-import]
from rasa_sdk.executor import CollectingDispatcher

from . import care_plan, emergency, triage
from .datastore import DatasetError, load
from .normalize import display, normalize_disease
from .text_utils import parse_number

logger = logging.getLogger(__name__)

# Load and validate the knowledge base at import time so a broken dataset
# surfaces when the action server starts, not silently mid-conversation.
try:
    KB = load()
except DatasetError:
    logger.exception("Knowledge base failed to load; the action server cannot triage")
    raise


# ---------------------------------------------------------------------------
# Slot <-> TriageState
# ---------------------------------------------------------------------------
def _as_list(value: Any) -> List[str]:
    if isinstance(value, list):
        return [str(v) for v in value if v]
    return []


def _as_int(value: Any) -> Optional[int]:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str) and value.strip().lstrip("-").isdigit():
        return int(value.strip())
    return None


def state_from_tracker(tracker: Tracker) -> triage.TriageState:
    return triage.TriageState(
        confirmed=_as_list(tracker.get_slot("confirmed_symptoms")),
        denied=_as_list(tracker.get_slot("denied_symptoms")),
        unknown=_as_list(tracker.get_slot("unknown_symptoms")),
        asked=_as_list(tracker.get_slot("asked_symptoms")),
        pending=tracker.get_slot("pending_symptom"),
        question_count=_as_int(tracker.get_slot("question_count")) or 0,
        age=_as_int(tracker.get_slot("user_age")),
        duration_days=_as_int(tracker.get_slot("duration_days")),
        severity=_as_int(tracker.get_slot("severity")),
        stage=tracker.get_slot("triage_state"),
        conditions=_as_list(tracker.get_slot("chronic_conditions")),
    )


def events_from_state(state: triage.TriageState) -> List[Dict[Text, Any]]:
    return [
        SlotSet("confirmed_symptoms", state.confirmed),
        SlotSet("denied_symptoms", state.denied),
        SlotSet("unknown_symptoms", state.unknown),
        SlotSet("asked_symptoms", state.asked),
        SlotSet("pending_symptom", state.pending),
        SlotSet("question_count", state.question_count),
        SlotSet("user_age", state.age),
        SlotSet("duration_days", state.duration_days),
        SlotSet("severity", state.severity),
        SlotSet("triage_state", state.stage),
        SlotSet("chronic_conditions", state.conditions),
        SlotSet("emergency_detected", False),
    ]


def dispatch(dispatcher: CollectingDispatcher, outcome: triage.Outcome) -> List[Dict[Text, Any]]:
    """Send the engine's messages and return the slot events they imply."""
    for message in outcome.messages:
        if message.payload is None:
            dispatcher.utter_message(text=message.text)
        else:
            dispatcher.utter_message(text=message.text, json_message=message.payload)
    return events_from_state(outcome.state) if outcome.state else []


# An upper bound on the conditions accepted from one message. The app's own
# profile screen has no limit, and this endpoint is reachable by anything that
# can talk to Rasa, so the engine caps what it will store rather than trusting
# the client.
MAX_CONDITIONS = 20
MAX_CONDITION_LENGTH = 80


def apply_metadata(tracker: Tracker, state: triage.TriageState) -> None:
    """Adopt intake values and profile conditions sent alongside the message.

    Values outside plausible bounds are discarded rather than stored, so the
    engine falls back to asking for them instead of scoring risk on a 999.

    Chronic conditions arrive from the app's stored health profile and are
    never asked for conversationally. They are only ever *added* to the state:
    a follow-up message that omits them must not wipe the ones the first
    message established, because the app sends them once, with the opening
    symptom description.
    """
    metadata = (tracker.latest_message or {}).get("metadata") or {}
    for key, attribute in (("age", "age"), ("duration", "duration_days"),
                           ("severity", "severity")):
        value = _as_int(metadata.get(key))
        if value is not None:
            setattr(state, attribute, value)

    conditions = _as_condition_list(metadata.get("conditions"))
    if conditions:
        state.conditions = conditions

    triage.sanitize_intake(state)


def _as_condition_list(raw: Any) -> List[str]:
    """Clean a client-supplied condition list into something safe to store."""
    if not isinstance(raw, (list, tuple)):
        return []
    cleaned: List[str] = []
    for item in raw:
        if not isinstance(item, str):
            continue
        text = item.strip()[:MAX_CONDITION_LENGTH]
        if text and text not in cleaned:
            cleaned.append(text)
        if len(cleaned) >= MAX_CONDITIONS:
            break
    return cleaned


def latest_text(tracker: Tracker) -> str:
    return ((tracker.latest_message or {}).get("text") or "").strip()


def emergency_events(flag: emergency.RedFlag) -> List[Dict[Text, Any]]:
    """Clear the assessment and hand off to the escalation action.

    The message itself is emitted by ActionTriggerEmergency via FollowupAction
    rather than dispatched here, so the emergency-override rule cannot also
    fire and send it a second time.

    The category rides along in a slot so the escalation action knows whether
    to send the emergency-department message or the crisis-line one. A crisis
    phrase is never logged: it is the most sensitive thing a user can type
    here, and knowing that one was matched is all an operator needs.
    """
    if flag.is_crisis:
        logger.info("Crisis red flag detected")
    else:
        logger.info("Emergency red flag detected: %s", flag.phrase)
    events = events_from_state(triage.TriageState())
    events.extend([
        SlotSet("emergency_detected", True),
        SlotSet("emergency_reason", None if flag.is_crisis else flag.phrase),
        SlotSet("red_flag_category", flag.category),
        FollowupAction("action_trigger_emergency"),
    ])
    return events


def guard_emergency(
    tracker: Tracker, state: triage.TriageState
) -> Optional[List[Dict[Text, Any]]]:
    """Return escalation events if this turn contains a red flag, else None."""
    flag = triage.classify_red_flag(latest_text(tracker), state)
    if flag is None:
        return None
    return emergency_events(flag)


# ---------------------------------------------------------------------------
# Triage actions
# ---------------------------------------------------------------------------
class ActionTriggerEmergency(Action):
    """Emit the escalation message and release the emergency flag.

    Clearing emergency_detected here is what stops the emergency-override rule
    from re-firing on every subsequent turn for the rest of the session.
    """

    def name(self) -> Text:
        return "action_trigger_emergency"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        category = tracker.get_slot("red_flag_category") or emergency.CATEGORY_EMERGENCY
        reason = tracker.get_slot("emergency_reason")
        outcome = triage.red_flag_outcome(
            emergency.RedFlag(phrase=reason or "", category=category)
        )
        for message in outcome.messages:
            dispatcher.utter_message(text=message.text, json_message=message.payload)
        return [
            SlotSet("emergency_detected", False),
            SlotSet("emergency_reason", None),
            SlotSet("red_flag_category", None),
        ]


class ActionDynamicFollowupQuestion(Action):
    """Entry point: the user has described symptoms in free text."""

    def name(self) -> Text:
        return "action_dynamic_followup_question"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        state = state_from_tracker(tracker)
        escalation = guard_emergency(tracker, state)
        if escalation is not None:
            return escalation

        apply_metadata(tracker, state)
        outcome = triage.start(KB, latest_text(tracker), state)

        # Symptoms confirmed from free text can themselves be red flags.
        flag = triage.classify_red_flag(None, outcome.state)
        if flag is not None:
            return emergency_events(flag)
        return dispatch(dispatcher, outcome)


class ActionHandleInform(Action):
    """A number in reply to one of the intake questions."""

    def name(self) -> Text:
        return "action_handle_inform"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        state = state_from_tracker(tracker)
        escalation = guard_emergency(tracker, state)
        if escalation is not None:
            return escalation

        apply_metadata(tracker, state)
        value = parse_number(latest_text(tracker))
        attribute = {
            triage.STAGE_AGE: "age",
            triage.STAGE_DURATION: "duration_days",
            triage.STAGE_SEVERITY: "severity",
        }.get(state.stage)

        if attribute is None:
            # Not answering an intake question -- treat it as more symptoms.
            outcome = triage.start(KB, latest_text(tracker), state)
            return dispatch(dispatcher, outcome)

        if value is None:
            dispatcher.utter_message(
                text="Sorry, I need a number for that. Could you try again?",
                json_message={"type": "question", "input_type": "number"},
            )
            return []

        problem = triage.validate_intake(attribute, value)
        if problem is not None:
            dispatcher.utter_message(
                text=problem,
                json_message={"type": "question", "question": problem,
                              "question_text": problem, "input_type": "number"},
            )
            return []

        setattr(state, attribute, value)
        return dispatch(dispatcher, triage.advance(KB, state))


class _AnswerHandler:
    """Shared handling for yes / no / not-sure replies to a follow-up.

    A plain mixin rather than an Action subclass: rasa_sdk registers every
    subclass of Action it can find and calls name() on each, so an abstract
    Action would abort action-server startup with "An action must implement a
    name".
    """

    feedback_reply = "Thank you for your feedback! Take care."

    def record(self, state: triage.TriageState, symptom: str) -> None:
        raise NotImplementedError

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        state = state_from_tracker(tracker)
        escalation = guard_emergency(tracker, state)
        if escalation is not None:
            return escalation

        if state.stage == triage.STAGE_FEEDBACK:
            dispatcher.utter_message(text=self.feedback_reply)
            return [SlotSet("triage_state", None)]

        if not state.pending:
            # Nothing was asked, so there is nothing to answer. Ask the user
            # to describe symptoms rather than silently wiping the session.
            dispatcher.utter_message(
                text="Could you tell me what symptoms you're experiencing?",
                json_message={"type": "clarification", "input_type": "text"},
            )
            return [SlotSet("pending_symptom", None)]

        self.record(state, state.pending)
        state.pending = None

        flag = triage.classify_red_flag(None, state)
        if flag is not None:
            return emergency_events(flag)
        return dispatch(dispatcher, triage.advance(KB, state))


class ActionHandleAffirm(_AnswerHandler, Action):
    def name(self) -> Text:
        return "action_handle_affirm"

    def record(self, state: triage.TriageState, symptom: str) -> None:
        state.confirm(symptom)


class ActionHandleDeny(_AnswerHandler, Action):
    """A "no" is evidence too.

    It is recorded on the state and fed to the scorer as negative evidence.
    Previously denials only pruned a candidate list that the final ranking
    never consulted, so answering "no" changed nothing about the result.
    """

    feedback_reply = "Thank you for your feedback! We will use it to improve."

    def name(self) -> Text:
        return "action_handle_deny"

    def record(self, state: triage.TriageState, symptom: str) -> None:
        state.deny(symptom)


class ActionHandleUnsure(_AnswerHandler, Action):
    """"Not sure" is missing data, not evidence -- excluded from scoring."""

    def name(self) -> Text:
        return "action_handle_unsure"

    def record(self, state: triage.TriageState, symptom: str) -> None:
        state.mark_unknown(symptom)


# ---------------------------------------------------------------------------
# Information actions
# ---------------------------------------------------------------------------
def _requested_disease(tracker: Tracker) -> Optional[str]:
    raw = tracker.get_slot("disease_entity") or tracker.get_slot("disease")
    return normalize_disease(raw) if raw else None


class ActionDiseaseDescription(Action):
    def name(self) -> Text:
        return "action_disease_description"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        events = [SlotSet("pending_symptom", None)]
        disease = _requested_disease(tracker)
        if not disease:
            dispatcher.utter_message(text="Please specify which disease you'd like to know about.")
            return events

        description = KB.description_of(disease)
        if description:
            dispatcher.utter_message(
                text="**{}**\n\n{}{}".format(display(disease), description, triage.DISCLAIMER)
            )
        else:
            dispatcher.utter_message(
                text="I don't have description data for *{}*.".format(display(disease))
            )
        return events


class ActionDiseasePrecaution(Action):
    def name(self) -> Text:
        return "action_disease_precaution"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        events = [SlotSet("pending_symptom", None)]
        disease = _requested_disease(tracker)
        if not disease:
            dispatcher.utter_message(text="Please specify which disease you'd like precautions for.")
            return events

        if disease not in KB.precautions:
            dispatcher.utter_message(
                text="I don't have precaution data for *{}*.".format(display(disease))
            )
            return events

        plan = care_plan.get_care_plan(disease)
        body = "\n".join(care_plan.flatten(plan))
        if plan.get("goal"):
            body = "_{}_\n\n{}".format(plan["goal"], body)
        dispatcher.utter_message(
            text="**What you can do for {}:**\n\n{}{}".format(
                display(disease), body, triage.DISCLAIMER
            )
        )
        return events


_VACCINATION_SCHEDULES = {
    "pregnancy": (
        ("pregnancy", "pregnant", "tt", "mother", "expecting"),
        "**Pregnancy Vaccination Schedule:**\n\n"
        "* Tetanus Toxoid (TT) — 2 doses recommended\n"
        "* Flu vaccine — safe during pregnancy\n"
        "* Consult your OB-GYN for a personalised schedule",
    ),
    "newborn": (
        ("newborn", "new born", "infant", "baby"),
        "**0–6 Months Vaccination Schedule:**\n\n"
        "* BCG — at birth\n"
        "* OPV (Oral Polio Vaccine) — at birth, 6w, 10w, 14w\n"
        "* Hepatitis B — at birth, 6w, 14w\n"
        "* DPT — 6w, 10w, 14w",
    ),
}

_VACCINATION_DEFAULT = (
    "**Standard Vaccination Schedule:**\n\n"
    "* 0–6 months: BCG, OPV, Hepatitis B, DPT\n"
    "* 6–12 months: Measles, DPT booster\n"
    "* Pregnancy: TT vaccine (2 doses)\n\n"
    "Please share your age or category for a more specific schedule."
)

_VACCINATION_6_12 = (
    "**6–12 Months Vaccination Schedule:**\n\n"
    "* Measles — 9 months\n"
    "* DPT Booster — 16–24 months\n"
    "* Hepatitis A — 12 months"
)

_VACCINATION_DISCLAIMER = (
    "\n\nPlease consult a pediatrician or healthcare provider to confirm the "
    "appropriate vaccination schedule."
)


class ActionVaccinationSchedule(Action):
    def name(self) -> Text:
        return "action_vaccination_schedule"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        text = latest_text(tracker).lower()
        months = parse_number(text) if "month" in text else None

        message = _VACCINATION_DEFAULT
        for keywords, schedule in _VACCINATION_SCHEDULES.values():
            if any(keyword in text for keyword in keywords):
                message = schedule
                break
        else:
            if months is not None:
                message = (
                    _VACCINATION_SCHEDULES["newborn"][1] if months <= 6
                    else _VACCINATION_6_12
                )

        dispatcher.utter_message(text=message + _VACCINATION_DISCLAIMER + triage.DISCLAIMER)
        return [SlotSet("pending_symptom", None)]


class ActionFindHospitals(Action):
    """Ask the app to run its own nearby-hospital search.

    The action server has no access to the user's location, so it cannot rank
    facilities. It signals intent and the Flutter client performs the lookup
    against the places API with the device's coordinates -- replacing a stub
    that returned three invented hospitals with plausible-looking phone numbers.
    """

    def name(self) -> Text:
        return "action_find_hospitals"

    def run(self, dispatcher, tracker, domain) -> List[Dict[Text, Any]]:
        dispatcher.utter_message(
            text="Let me find medical facilities near you.",
            json_message={
                "type": "hospitals",
                "action": "find_nearby",
                "radius_m": 5000,
            },
        )
        return []
