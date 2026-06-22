import re
from typing import List, Dict, Any
# pyrefly: ignore [missing-import]
from rasa_sdk import Tracker
# pyrefly: ignore [missing-import]
from rasa_sdk.executor import CollectingDispatcher
# pyrefly: ignore [missing-import]
from rasa_sdk.events import SlotSet, FollowupAction

EMERGENCY_SYMPTOMS = [
    "chest pain", "severe chest pain", "chest tightness", "pain in chest", "chest hurts", "crushing chest pressure",
    "shortness of breath", "difficulty breathing", "cannot breathe", "cant breathe",
    "hard to breathe", "breathing difficulty", "breathless", "choking",
    "unconscious", "unconsciousness", "fainted", "not responding", "loss of consciousness",
    "severe bleeding", "heavy bleeding", "bleeding heavily", "hemorrhage", "coughing blood", "vomiting blood",
    "stroke", "face drooping", "arm weakness", "sudden numbness", "stroke symptoms", "slurred speech", "sudden weakness", "unilateral weakness",
    "heart attack", "pressure in chest",
    "thunderclap headache", "worst headache of life",
    "severe allergic reaction", "anaphylaxis", "throat swelling"
]

EMERGENCY_MSG = (
    "⚠️ Medical Emergency Detected\n\n"
    "Please seek immediate medical attention immediately."
)

def check_emergency(tracker: Tracker) -> bool:
    """
    Checks if the user's latest message contains any emergency symptoms.
    """
    message = tracker.latest_message or {}
    text = (message.get("text") or "").lower()
    for keyword in EMERGENCY_SYMPTOMS:
        if re.search(r'\b' + re.escape(keyword) + r'\b', text):
            return True
    return False

def handle_emergency() -> List[Any]:
    """
    Returns events to reset the triage state instantly when an emergency is detected.
    """
    return [
        SlotSet("emergency_detected", True),
        SlotSet("candidate_diseases", []),
        SlotSet("confirmed_symptoms", []),
        SlotSet("asked_symptoms", []),
        SlotSet("pending_symptom", None),
        SlotSet("question_count", 0),
        SlotSet("triage_state", None),
        FollowupAction("action_trigger_emergency")
    ]
