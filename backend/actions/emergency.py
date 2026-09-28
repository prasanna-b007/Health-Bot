"""Red-flag detection: medical emergencies and mental-health crises.

Pure detection only -- the Rasa events that reset the conversation live in
actions.py, so this module can be tested without a tracker.

Three things matter here, and originally only the first existed:

* **detect_in_text** -- red flags in whatever the user just typed.
* **detect_in_symptoms** -- red flags among the symptoms confirmed so far.
  This closes a real gap: once triage starts the app sends only "yes" and
  "no", so a user confirming chest pain in answer to a follow-up question
  never produced any text for the keyword matcher to see, and the emergency
  path was never reached.
* **Categories.** Suicidal ideation was in the same keyword list as chest
  pain and produced the same response -- "go to the nearest emergency
  department". That is the wrong instruction for a mental-health crisis, told
  to someone least able to argue with it. CATEGORY_CRISIS routes to a crisis
  line instead. See triage.crisis_outcome.

Matching is deliberately blunt, but no longer blind. Two filters now run
before a phrase counts, and the asymmetry between them is the whole design:
over-triggering costs the user one alarming screen, under-triggering can cost
considerably more.
"""
from dataclasses import dataclass
from typing import Iterable, List, Optional, Set

from .normalize import normalize, normalize_symptom
from .text_utils import clauses, is_negated

CATEGORY_EMERGENCY = "emergency"
CATEGORY_CRISIS = "crisis"

# Free-text red flags. Stored normalised (lowercase, no apostrophes) and
# matched against normalised input, so "can't breathe", "cant breathe" and
# "Cannot Breathe" all hit -- the previous matcher compared against raw text
# and the apostrophe in "can't" defeated the word-boundary regex.
EMERGENCY_PHRASES: List[str] = [
    # Cardiac
    "chest pain", "severe chest pain", "chest tightness", "pain in chest",
    "chest hurts", "crushing chest pressure", "pressure in chest", "heart attack",
    # Respiratory
    "shortness of breath", "difficulty breathing", "cannot breathe",
    "cant breathe", "hard to breathe", "breathing difficulty", "breathless",
    "choking", "gasping for air",
    # Consciousness
    "unconscious", "unconsciousness", "fainted", "not responding",
    "loss of consciousness", "passed out", "unresponsive",
    # Bleeding
    "severe bleeding", "heavy bleeding", "bleeding heavily", "hemorrhage",
    "haemorrhage", "coughing blood", "vomiting blood", "blood in vomit",
    # Stroke. The reversed phrasings are here because the evaluation suite
    # caught "my speech is slurred and one side feels weak" -- a textbook
    # stroke description, in the words people actually use -- sailing straight
    # past a list that only knew "slurred speech".
    "stroke", "face drooping", "face is drooping", "arm weakness",
    "sudden numbness", "stroke symptoms", "slurred speech", "speech is slurred",
    "slurring my words", "sudden weakness", "unilateral weakness",
    "one side feels weak", "one side is weak", "weakness on one side",
    "cant move one side", "cant feel one side",
    # Neurological
    "thunderclap headache", "worst headache of life", "seizure", "convulsions",
    # Allergic
    "severe allergic reaction", "anaphylaxis", "throat swelling",
    "swollen throat", "tongue swelling", "throat is swelling",
    "throat is closing", "tongue is swelling", "cant swallow",
    # Poisoning
    "poisoning",
]

# Mental-health crisis. Separated from EMERGENCY_PHRASES because the response
# differs: an ambulance is not the first thing someone in this position needs
# to be told about, and a crisis line is staffed for exactly this call.
# "overdose" sits here rather than above on the same reasoning -- it is far
# more often disclosed as intent than reported as a bystander emergency, and
# the crisis response names emergency services anyway.
CRISIS_PHRASES: List[str] = [
    "suicidal", "suicide", "kill myself", "killing myself", "end my life",
    "want to end my life", "want to die", "better off dead", "no reason to live",
    "self harm", "self harming", "harm myself", "hurt myself", "cut myself",
    # Gerunds and the "thinking about" framing, which is how the thought is
    # most often admitted first -- "hurt myself" alone missed "thinking about
    # hurting myself", and this is not a list to be narrowly literal with.
    "harming myself", "hurting myself", "cutting myself", "ending my life",
    "end it all", "ending it all", "take my own life", "taking my own life",
    "overdose", "overdosed", "took too many pills",
    # Phrased as an absence rather than an intent, which is how it is most
    # often said first. These are matched before the negation filter runs --
    # see classify_text -- because the negator is the disclosure.
    "dont want to live", "do not want to live", "dont want to be here",
    "dont want to wake up", "cant go on", "cant do this anymore",
    "nothing to live for", "want to disappear",
]

# Canonical dataset symptoms that are themselves red flags -- these are what a
# user can confirm during follow-up questioning, so every entry must be a name
# dataset.csv actually uses. Free-text phrasings such as "vomiting blood" or
# "loss of consciousness" have no dataset equivalent and live in
# EMERGENCY_PHRASES above instead; test_emergency guards the distinction.
EMERGENCY_SYMPTOMS: Set[str] = {
    "chest pain",
    "breathlessness",
    "blood in sputum",
    "altered sensorium",
    "slurred speech",
    "weakness of one body side",
    "acute liver failure",
}

EMERGENCY_MESSAGE = (
    "⚠️ Medical Emergency Detected\n\n"
    "Your symptoms may indicate a medical emergency. Please call your local "
    "emergency number or go to the nearest emergency department now."
)

CRISIS_MESSAGE = (
    "You matter, and help is available right now.\n\n"
    "Please reach out to a crisis line — they are free, confidential, and "
    "staffed by people trained for exactly this conversation. If you are in "
    "immediate danger, call your local emergency number.\n\n"
    "You do not have to work through this alone."
)

# Phrases meaning the red flag happened in the past rather than now. A user
# writing "my father had a heart attack last year" is giving family history,
# not calling for an ambulance.
#
# Two things are NOT here, both on purpose. Third-party pronouns: "my father
# is having chest pain" reports an emergency happening to someone in the room,
# and a person reaching for a symptom checker on someone else's behalf should
# get the emergency screen, not a questionnaire. And bare past tense: "I had
# a seizure" is most often said within the hour, so only an explicit time
# marker is treated as history. Both filters would have suppressed real
# emergencies to save a false alarm, which is the wrong trade.
_HISTORY_MARKERS = (
    "last year", "last month", "years ago", "months ago", "weeks ago",
    "a year ago", "long ago", "used to", "history of", "family history",
    "in the past", "previously", "when i was", "as a child", "since childhood",
    "back then", "recovered from", "have had", "has had",
)

_NORMALIZED_EMERGENCY = sorted(
    {normalize(p) for p in EMERGENCY_PHRASES}, key=len, reverse=True
)
_NORMALIZED_CRISIS = sorted(
    {normalize(p) for p in CRISIS_PHRASES}, key=len, reverse=True
)


@dataclass(frozen=True)
class RedFlag:
    """What was found, and which response it calls for."""

    phrase: str
    category: str

    @property
    def is_crisis(self) -> bool:
        return self.category == CATEGORY_CRISIS


def _is_history(clause: str) -> bool:
    return any(marker in clause for marker in _HISTORY_MARKERS)


def _find(clause: str, phrases: Iterable[str]) -> Optional[str]:
    for phrase in phrases:
        index = clause.find(phrase)
        if index == -1:
            continue
        if is_negated(clause, index):
            continue
        return phrase
    return None


def classify_text(text: Optional[str]) -> Optional[RedFlag]:
    """The red flag in this text and its category, or None.

    Crisis phrases are tested first: "I took an overdose and my chest hurts"
    should reach a crisis line, not a triage questionnaire.
    """
    haystack = normalize(text)
    if not haystack:
        return None

    for clause in clauses(haystack):
        crisis = _find(clause, _NORMALIZED_CRISIS)
        if crisis is not None:
            return RedFlag(phrase=crisis, category=CATEGORY_CRISIS)

    for clause in clauses(haystack):
        if _is_history(clause):
            continue
        emergency = _find(clause, _NORMALIZED_EMERGENCY)
        if emergency is not None:
            return RedFlag(phrase=emergency, category=CATEGORY_EMERGENCY)
    return None


def classify_symptoms(symptoms: Iterable[str]) -> Optional[RedFlag]:
    """The first confirmed symptom that is a red flag, or None.

    No negation or history filtering: these are symptoms the user has
    explicitly confirmed in answer to a direct question about right now.
    """
    for symptom in symptoms or ():
        key = normalize_symptom(symptom)
        if key in EMERGENCY_SYMPTOMS:
            return RedFlag(phrase=key, category=CATEGORY_EMERGENCY)
    return None


def classify(
    text: Optional[str] = None, symptoms: Iterable[str] = ()
) -> Optional[RedFlag]:
    """Red flag from either the latest message or the confirmed symptom list."""
    return classify_text(text) or classify_symptoms(symptoms)


# ---------------------------------------------------------------------------
# Phrase-only API
# ---------------------------------------------------------------------------
# Kept because callers that only need "is this an emergency" read better
# without unpacking a dataclass. Each returns the matched phrase or None.
def detect_in_text(text: Optional[str]) -> Optional[str]:
    flag = classify_text(text)
    return flag.phrase if flag else None


def detect_in_symptoms(symptoms: Iterable[str]) -> Optional[str]:
    flag = classify_symptoms(symptoms)
    return flag.phrase if flag else None


def detect(text: Optional[str] = None, symptoms: Iterable[str] = ()) -> Optional[str]:
    flag = classify(text=text, symptoms=symptoms)
    return flag.phrase if flag else None
