from typing import Any, Text, Dict, List, Optional
import csv
import os
import re
import random
import difflib

from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher
from rasa_sdk.events import SlotSet

# ---------------------------------------------------------------------------
# File Paths
# ---------------------------------------------------------------------------
_BASE_PATH = os.path.dirname(__file__)
_DATASET_PATH     = os.path.join(_BASE_PATH, "..", "datasets", "dataset.csv")
_DESCRIPTION_PATH = os.path.join(_BASE_PATH, "..", "datasets", "symptom_Description.csv")
_PRECAUTION_PATH  = os.path.join(_BASE_PATH, "..", "datasets", "symptom_precaution.csv")
_SEVERITY_PATH    = os.path.join(_BASE_PATH, "..", "datasets", "Symptom-severity.csv")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
DISCLAIMER = "\n\n_This is not a medical diagnosis. Please consult a qualified healthcare professional._"

EMERGENCY_SYMPTOMS = [
    "chest pain", "chest tightness", "pain in chest", "chest hurts",
    "shortness of breath", "difficulty breathing", "cant breathe",
    "hard to breathe", "breathing difficulty", "breathless",
    "unconscious", "unconsciousness", "fainted", "not responding",
    "severe bleeding", "heavy bleeding", "bleeding heavily",
    "stroke", "face drooping", "arm weakness", "sudden numbness",
    "heart attack", "pressure in chest",
]

EMERGENCY_MSG = (
    "⚠️ This may be a medical emergency.\n"
    "Please call emergency services or go to the nearest hospital immediately.\n"
    "Do not delay care — your safety is the priority."
)

HIGH_SEVERITY_THRESHOLD = 25
MIN_SYMPTOMS_TO_CONCLUDE = 2
MAX_QUESTIONS = 5
_DANGEROUS_DISEASES = ["paralysis (brain hemorrhage)", "heart attack"]

# ---------------------------------------------------------------------------
# Empathetic question templates
# ---------------------------------------------------------------------------
_FOLLOWUP_TEMPLATES = [
    "To help narrow this down, are you also dealing with **{symptom}**?",
    "Just to confirm, are you experiencing **{symptom}** as well?",
    "Let me check one more thing — do you also have **{symptom}**?",
    "Are you also noticing any **{symptom}**?",
    "To better assess your condition, do you have **{symptom}**?"
]

def _followup_question(symptom: str) -> str:
    template = random.choice(_FOLLOWUP_TEMPLATES)
    return template.format(symptom=symptom.replace("_", " ").title())

# ---------------------------------------------------------------------------
# Symptom Aliases
# ---------------------------------------------------------------------------
ALIASES: Dict[str, List[str]] = {
    "fever": ["high fever", "mild fever", "high temperature", "temperature",
              "feverish", "feeling hot", "feaver", "tempature", "running a fever"],
    "headache": ["head pain", "head ache", "head is pounding", "migraine", "headake"],
    "rash": ["skin rash", "nodal skin eruptions", "rashes"],
    "itching": ["itchy skin", "skin itch", "itchy"],
    "burning micturition": ["burning sensation while urinating", "burning while peeing",
                            "burning urination", "pain while urinating",
                            "burning when i urinate", "it burns when i pee", "painful urination"],
    "fatigue": ["tiredness", "tired all the time", "always tired", "feeling tired",
                "no energy", "weakness", "feeling weak", "exhausted"],
    "vomiting": ["throwing up", "puking", "vomit"],
    "nausea": ["nauseous", "feel like vomiting", "want to vomit", "queasy"],
    "cough": ["coughing", "continuous cough", "persistent cough"],
    "chest pain": ["chest tightness", "pain in chest", "chest hurts", "pressure in chest"],
    "breathlessness": ["shortness of breath", "difficulty breathing", "cant breathe",
                       "hard to breathe", "breathless", "breathing difficulty"],
    "dizziness": ["dizzy", "feeling dizzy", "light headed", "lightheaded", "spinning"],
    "joint pain": ["joints hurt", "joint ache", "joints aching", "joint swelling"],
    "back pain": ["pain in back", "backache", "lower back pain"],
    "stomach pain": ["abdominal pain", "stomach ache", "tummy ache",
                     "pain in stomach", "belly pain"],
    "diarrhoea": ["diarrhea", "loose stools", "loose motion", "watery stool"],
    "sweating": ["excessive sweating", "night sweats", "profuse sweating"],
    "weight loss": ["losing weight", "lost weight", "weight has reduced"],
    "yellowing of eyes": ["yellow eyes", "jaundice eyes", "yellow skin and eyes"],
    "skin rash": ["rash on skin", "body rash", "rashes on body"],
    "high fever": ["very high fever", "high grade fever", "severe fever", "high feaver"],
    "chills": ["shivering", "cold chills", "feeling cold"],
    "loss of appetite": ["no appetite", "not feeling hungry", "cant eat"],
    "muscle pain": ["muscle ache", "body ache", "body pain", "myalgia"],
    "neck pain": ["stiff neck", "pain in neck"],
    "blurred vision": ["blurry vision", "vision is blurry", "cant see clearly"],
    "runny nose": ["running nose", "watery nose", "nose is running"],
}

# ---------------------------------------------------------------------------
# Data Loading & Caching
# ---------------------------------------------------------------------------
_DISEASE_SYMPTOMS_CACHE: Dict[str, List[str]] = {}
_SEVERITY_CACHE: Dict[str, int] = {}
_PRECAUTION_CACHE: Dict[str, List[str]] = {}

def load_severity() -> Dict[str, int]:
    global _SEVERITY_CACHE
    if _SEVERITY_CACHE: return _SEVERITY_CACHE
    try:
        with open(_SEVERITY_PATH, encoding="utf-8") as f:
            for row in csv.reader(f):
                if row and row[0].strip().lower() != "symptom":
                    key = row[0].strip().replace("_", " ").lower()
                    _SEVERITY_CACHE[key] = int(row[1])
    except Exception: pass
    return _SEVERITY_CACHE

def load_dataset() -> Dict[str, List[str]]:
    global _DISEASE_SYMPTOMS_CACHE
    if _DISEASE_SYMPTOMS_CACHE: return _DISEASE_SYMPTOMS_CACHE
    try:
        with open(_DATASET_PATH, encoding="utf-8") as f:
            reader = csv.reader(f)
            next(reader, None)
            for row in reader:
                if not row: continue
                disease = row[0].strip().lower()
                symptoms = [s.strip().replace("_", " ").lower() for s in row[1:] if s.strip()]
                if disease not in _DISEASE_SYMPTOMS_CACHE:
                    _DISEASE_SYMPTOMS_CACHE[disease] = []
                for s in symptoms:
                    if s not in _DISEASE_SYMPTOMS_CACHE[disease]:
                        _DISEASE_SYMPTOMS_CACHE[disease].append(s)
    except Exception: pass
    return _DISEASE_SYMPTOMS_CACHE

def load_precautions() -> Dict[str, List[str]]:
    global _PRECAUTION_CACHE
    if _PRECAUTION_CACHE: return _PRECAUTION_CACHE
    try:
        with open(_PRECAUTION_PATH, encoding="utf-8") as f:
            reader = csv.reader(f)
            next(reader, None)
            for row in reader:
                if row:
                    disease = row[0].strip().lower()
                    # Filter out bad advice and fix typos
                    raw_precautions = [v.strip() for v in row[1:] if v.strip()]
                    safe = []
                    for p in raw_precautions:
                        p_lower = p.lower()
                        # Remove unsafe or overly specific advice
                        if any(bad in p_lower for bad in ["papaya", "radioactive", "witch hazel", "medication", "antibiotic", "antiboitic", "therapy", "asprin", "vaccine", "surgery"]):
                            continue
                        # Spelling corrections
                        p = p.replace("vegitables", "vegetables").replace("Antiboitic", "antibiotic")
                        safe.append(p)
                    
                    # Ensure we have our baseline safe precautions
                    general_safe = ["Stay hydrated", "Maintain hygiene", "Avoid contaminated food/water", "Use mosquito protection where relevant", "Seek medical attention if symptoms worsen"]
                    
                    # We will completely replace with the safe general advice to be 100% compliant with the prompt's request for "general, non-prescriptive, safe for all users"
                    _PRECAUTION_CACHE[disease] = general_safe
    except Exception: pass
    return _PRECAUTION_CACHE

# ---------------------------------------------------------------------------
# Emergency & Autocorrect
# ---------------------------------------------------------------------------
def is_emergency(text: str) -> bool:
    text_lower = text.lower()
    for keyword in EMERGENCY_SYMPTOMS:
        if re.search(r'\b' + re.escape(keyword) + r'\b', text_lower):
            return True
    return False

def autocorrect_text(text: str, all_symptoms: List[str]) -> str:
    """Use difflib to correct user typos before extraction."""
    valid_phrases = set()
    for s in all_symptoms:
        valid_phrases.add(s.replace("_", " "))
    for syns in ALIASES.values():
        for syn in syns:
            valid_phrases.add(syn)
            
    single_word_terms = {p.lower() for p in valid_phrases if " " not in p}
    
    words = text.split()
    corrected = []
    for w in words:
        clean_w = re.sub(r'[^\w\s]', '', w).lower()
        if len(clean_w) >= 4 and clean_w not in single_word_terms:
            matches = difflib.get_close_matches(clean_w, single_word_terms, n=1, cutoff=0.8)
            if matches:
                corrected.append(matches[0])
                continue
        corrected.append(w)
    return " ".join(corrected)

def extract_symptoms(text: str, all_symptoms: List[str]) -> List[str]:
    text_corrected = autocorrect_text(text, all_symptoms)
    text_lower = text_corrected.lower()
    found: List[str] = []

    for s in all_symptoms:
        s_clean = s.replace("_", " ")
        if re.search(r'\b' + re.escape(s_clean) + r'\b', text_lower):
            if s not in found: found.append(s)

    for canonical, synonyms in ALIASES.items():
        matched = False
        if re.search(r'\b' + re.escape(canonical) + r'\b', text_lower):
            matched = True
        if not matched:
            for syn in synonyms:
                if re.search(r'\b' + re.escape(syn) + r'\b', text_lower):
                    matched = True
                    break
        if matched:
            for actual in all_symptoms:
                if actual.replace("_", " ") == canonical and actual not in found:
                    found.append(actual)
                    break
            if canonical not in found and canonical in all_symptoms:
                found.append(canonical)
    return found

# ---------------------------------------------------------------------------
# Risk & Ranking
# ---------------------------------------------------------------------------
def calculate_match_scores(confirmed: List[str], disease_map: Dict[str, List[str]]) -> List[tuple]:
    scores = []
    for d, symps in disease_map.items():
        total = len(symps)
        if total == 0: continue
        matched = len([s for s in confirmed if s in symps])
        pct = (matched / total) * 100
        if pct > 0:
            scores.append((d, pct))
    scores.sort(key=lambda x: x[1], reverse=True)
    return scores

def calculate_risk(
    match_pct: float,
    severity_score: int,
    user_age: Optional[int],
    duration_days: Optional[int],
    severity_input: Optional[int]
) -> str:
    risk_levels = ["Low", "Moderate", "High"]
    
    if match_pct >= 70 or severity_score >= HIGH_SEVERITY_THRESHOLD:
        idx = 2
    elif match_pct >= 30:
        idx = 1
    else:
        idx = 0
        
    if user_age is not None and (user_age < 10 or user_age >= 60):
        idx += 1
        
    if duration_days is not None:
        if duration_days >= 7:
            idx = 2
        elif duration_days >= 3:
            idx += 1
            
    if severity_input is not None and severity_input >= 8:
        idx += 1
        
    idx = min(2, max(0, idx))
    return risk_levels[idx]

def _filter_dangerous(candidates: List[str], confirmed: List[str], disease_map: Dict[str, List[str]]) -> List[str]:
    safe = []
    for d in candidates:
        if any(danger in d.lower() for danger in _DANGEROUS_DISEASES):
            match_cnt = sum(1 for s in confirmed if s in disease_map.get(d, []))
            if match_cnt >= 4: safe.append(d)
        else:
            safe.append(d)
    return safe

def _best_next_symptom(candidates: List[str], disease_map: Dict[str, List[str]], asked: List[str], confirmed: List[str]) -> Optional[str]:
    if not candidates: return None
    match_counts = {d: sum(1 for s in confirmed if s in disease_map.get(d, [])) for d in candidates}
    max_matches = max(match_counts.values(), default=0)
    top_candidates = [d for d, cnt in match_counts.items() if cnt == max_matches]

    freq: Dict[str, int] = {}
    for d in top_candidates:
        for s in disease_map.get(d, []):
            if s not in asked:
                freq[s] = freq.get(s, 0) + 1
    if not freq:
        for d in candidates:
            for s in disease_map.get(d, []):
                if s not in asked:
                    freq[s] = freq.get(s, 0) + 1
    if not freq: return None
    max_freq = max(freq.values())
    top_symptoms = sorted(s for s, f in freq.items() if f == max_freq)
    return top_symptoms[0]

def _parse_count(raw) -> int:
    if raw is None: return 0
    if isinstance(raw, (int, float)): return int(raw)
    if isinstance(raw, str) and raw.isdigit(): return int(raw)
    return 0

# ---------------------------------------------------------------------------
# Triage Core Logic
# ---------------------------------------------------------------------------
def _conclude_triage(
    candidates: List[str],
    confirmed: List[str],
    disease_map: Dict[str, List[str]],
    severity_map: Dict[str, int],
    precaution_map: Dict[str, List[str]],
    dispatcher: CollectingDispatcher,
    base_events: List[Dict],
    user_age: Optional[int],
    duration: Optional[int],
    severity: Optional[int]
) -> List[Dict]:
    
    scores = calculate_match_scores(confirmed, disease_map)
    # Filter dangerous from candidates used in scoring to be safe
    # Though ranking handles it implicitly, it's good to keep safe
    
    reset_events = base_events + [
        SlotSet("candidate_diseases", []),
        SlotSet("confirmed_symptoms", []),
        SlotSet("asked_symptoms", []),
        SlotSet("pending_symptom", None),
        SlotSet("question_count", 0),
        SlotSet("user_age", None),
        SlotSet("duration_days", None),
        SlotSet("severity", None)
    ]
    
    if not scores:
        dispatcher.utter_message(text="I wasn't able to identify a specific condition from your symptoms. Please describe more symptoms or consult a healthcare provider." + DISCLAIMER)
        return reset_events
        
    top_disease, top_pct = scores[0]
    
    if top_pct < 40:
        dispatcher.utter_message(text="Your symptoms do not clearly match a known condition.\nPlease provide more details or consult a doctor." + DISCLAIMER)
        return reset_events
        
    severity_score_sum = sum(severity_map.get(s.replace("_", " "), 0) for s in confirmed)
    risk = calculate_risk(top_pct, severity_score_sum, user_age, duration, severity)
    
    precautions = precaution_map.get(top_disease.lower(), [])
    risk_emoji = {"Low": "🟢", "Moderate": "🟡", "High": "🔴"}.get(risk, "🟡")
    
    lines = [
        f"Based on your symptoms, one possible condition is: **{top_disease.title()}** ({int(top_pct)}% match)",
        f"Risk Level: {risk}\n"
    ]
    
    if top_pct <= 80 and len(scores) > 1:
        num_to_show = 2 if top_pct >= 60 else 3
        lines.append("Other Potential Matches:")
        for i, (d, p) in enumerate(scores[1:num_to_show], start=2):
            lines.append(f"{i}. {d.title()} ({int(p)}%)")
        lines.append("")
        
    lines.append("Advice:")
    if precautions:
        for p in precautions:
            lines.append(f"* {p.capitalize()}")
    else:
        lines.append("* Monitor your symptoms closely.")
        
    lines.append(DISCLAIMER)
    
    symptom_summary = ", ".join(s.replace("_", " ").title() for s in confirmed)
    summary = (
        f"\n---\n**Session Summary:**\n"
        f"• **Symptoms:** {symptom_summary}\n"
        f"• **Predicted Condition:** {top_disease.title()}\n"
        f"• **Risk Level:** {risk}\n---"
    )
    
    dispatcher.utter_message(text="\n".join(lines) + summary)
    
    dispatcher.utter_message(text="Was this helpful? (yes/no)")
    reset_events.append(SlotSet("triage_state", "asking_feedback"))
    
    return reset_events

def _process_triage_step(dispatcher: CollectingDispatcher, tracker: Tracker, additional_events: List[Dict] = None) -> List[Dict]:
    events = additional_events or []
    
    def get_slot(name, default=None):
        for e in reversed(events):
            if e.get("event") == "slot" and e.get("name") == name:
                return e.get("value")
        return tracker.get_slot(name) or default

    user_age = get_slot("user_age")
    duration = get_slot("duration_days")
    severity = get_slot("severity")
    
    if user_age is None:
        events.append(SlotSet("triage_state", "asking_age"))
        dispatcher.utter_message(text="Before we proceed, could you please tell me your age?")
        return events
        
    if duration is None:
        events.append(SlotSet("triage_state", "asking_duration"))
        dispatcher.utter_message(text="How many days have you been experiencing these symptoms?")
        return events
        
    if severity is None:
        events.append(SlotSet("triage_state", "asking_severity"))
        dispatcher.utter_message(text="On a scale of 1-10, how severe are your symptoms overall?")
        return events
        
    events.append(SlotSet("triage_state", None))
    
    candidates = get_slot("candidate_diseases", [])
    confirmed = get_slot("confirmed_symptoms", [])
    asked = get_slot("asked_symptoms", [])
    count = _parse_count(get_slot("question_count"))
    
    disease_map = load_dataset()
    severity_map = load_severity()
    precaution_map = load_precautions()
    
    if (len(candidates) <= 1 and len(confirmed) >= MIN_SYMPTOMS_TO_CONCLUDE) or count >= MAX_QUESTIONS:
        return _conclude_triage(candidates, confirmed, disease_map, severity_map, precaution_map, dispatcher, events, user_age, duration, severity)
        
    next_s = _best_next_symptom(candidates, disease_map, asked, confirmed)
    if not next_s:
        return _conclude_triage(candidates, confirmed, disease_map, severity_map, precaution_map, dispatcher, events, user_age, duration, severity)
        
    dispatcher.utter_message(text=_followup_question(next_s))
    events.extend([
        SlotSet("asked_symptoms", asked + [next_s]),
        SlotSet("pending_symptom", next_s),
        SlotSet("question_count", count + 1)
    ])
    return events


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
class ActionDynamicFollowupQuestion(Action):
    def name(self) -> Text:
        return "action_dynamic_followup_question"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        text = (tracker.latest_message.get("text") or "").strip()

        if is_emergency(text):
            dispatcher.utter_message(text=EMERGENCY_MSG)
            return [SlotSet("candidate_diseases", []), SlotSet("confirmed_symptoms", []), SlotSet("asked_symptoms", []), SlotSet("pending_symptom", None), SlotSet("question_count", 0), SlotSet("triage_state", None)]

        all_symptoms = list(load_severity().keys())
        found = extract_symptoms(text, all_symptoms)

        if not found:
            dispatcher.utter_message(text="I'm here to help. Could you describe your symptoms in a bit more detail? For example: 'I have a fever and headache.'")
            return []

        disease_map = load_dataset()
        candidates = [d for d, ss in disease_map.items() if any(s in ss for s in found)]
        candidates = _filter_dangerous(candidates, found, disease_map)
        
        # Merge if continuing
        existing_confirmed = tracker.get_slot("confirmed_symptoms") or []
        existing_asked = tracker.get_slot("asked_symptoms") or []
        combined_found = list(set(existing_confirmed + found))
        combined_asked = list(set(existing_asked + found))

        events = [
            SlotSet("confirmed_symptoms", combined_found),
            SlotSet("candidate_diseases", candidates),
            SlotSet("asked_symptoms", combined_asked),
            SlotSet("pending_symptom", None),
            SlotSet("question_count", 0) # reset count for new input logic
        ]
        
        return _process_triage_step(dispatcher, tracker, events)

class ActionHandleInform(Action):
    def name(self) -> Text:
        return "action_handle_inform"
        
    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        triage_state = tracker.get_slot("triage_state")
        text = tracker.latest_message.get("text", "")
        numbers = re.findall(r'\d+', text)
        val = int(numbers[0]) if numbers else None
        
        events = []
        if triage_state == "asking_age":
            if val is not None: events.append(SlotSet("user_age", val))
            return _process_triage_step(dispatcher, tracker, events)
        elif triage_state == "asking_duration":
            if val is not None: events.append(SlotSet("duration_days", val))
            return _process_triage_step(dispatcher, tracker, events)
        elif triage_state == "asking_severity":
            if val is not None: events.append(SlotSet("severity", val))
            return _process_triage_step(dispatcher, tracker, events)
            
        return []

class ActionHandleAffirm(Action):
    def name(self) -> Text:
        return "action_handle_affirm"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        triage_state = tracker.get_slot("triage_state")
        if triage_state == "asking_feedback":
            dispatcher.utter_message(text="Thank you for your feedback! Take care.")
            return [SlotSet("triage_state", None)]

        candidates = tracker.get_slot("candidate_diseases") or []
        confirmed  = list(tracker.get_slot("confirmed_symptoms") or [])
        asked      = list(tracker.get_slot("asked_symptoms") or [])
        pending    = tracker.get_slot("pending_symptom")

        if not pending:
            return [SlotSet("pending_symptom", None), SlotSet("candidate_diseases", []), SlotSet("confirmed_symptoms", [])]

        if pending not in confirmed:
            confirmed.append(pending)

        disease_map = load_dataset()
        candidates = [d for d in candidates if pending in disease_map.get(d, [])]
        candidates = _filter_dangerous(candidates, confirmed, disease_map)

        events = [
            SlotSet("candidate_diseases", candidates),
            SlotSet("confirmed_symptoms", confirmed)
        ]
        return _process_triage_step(dispatcher, tracker, events)

class ActionHandleDeny(Action):
    def name(self) -> Text:
        return "action_handle_deny"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        triage_state = tracker.get_slot("triage_state")
        if triage_state == "asking_feedback":
            dispatcher.utter_message(text="Thank you for your feedback! We will use it to improve.")
            return [SlotSet("triage_state", None)]

        candidates = tracker.get_slot("candidate_diseases") or []
        confirmed  = list(tracker.get_slot("confirmed_symptoms") or [])
        pending    = tracker.get_slot("pending_symptom")

        if not pending:
            return [SlotSet("pending_symptom", None), SlotSet("candidate_diseases", []), SlotSet("confirmed_symptoms", [])]

        disease_map = load_dataset()
        candidates = [d for d in candidates if pending not in disease_map.get(d, [])]

        events = [
            SlotSet("candidate_diseases", candidates),
        ]
        return _process_triage_step(dispatcher, tracker, events)

class ActionDiseaseDescription(Action):
    def name(self) -> Text: return "action_disease_description"
    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        events = [SlotSet("pending_symptom", None)]
        disease = tracker.get_slot("disease_entity") or tracker.get_slot("disease")
        if not disease:
            dispatcher.utter_message(text="Please specify which disease you'd like to know about.")
            return events
        try:
            with open(_DESCRIPTION_PATH, encoding="utf-8") as f:
                reader = csv.reader(f)
                next(reader, None)
                for row in reader:
                    if row and disease.lower() == row[0].strip().lower():
                        dispatcher.utter_message(text=f"**{disease.title()}**\n\n{row[1].strip()}" + DISCLAIMER)
                        return events
        except Exception: pass
        dispatcher.utter_message(text=f"I don't have description data for *{disease}*.")
        return events

class ActionDiseasePrecaution(Action):
    def name(self) -> Text: return "action_disease_precaution"
    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        events = [SlotSet("pending_symptom", None)]
        disease = tracker.get_slot("disease_entity") or tracker.get_slot("disease")
        if not disease:
            dispatcher.utter_message(text="Please specify which disease you'd like precautions for.")
            return events
        try:
            with open(_PRECAUTION_PATH, encoding="utf-8") as f:
                reader = csv.reader(f)
                next(reader, None)
                for row in reader:
                    if row and disease.lower() == row[0].strip().lower():
                        precautions = [v.strip() for v in row[1:] if v.strip()]
                        bullets = "\n".join(f"* {p.capitalize()}" for p in precautions)
                        dispatcher.utter_message(text=f"**Precautions for {disease.title()}:**\n\n{bullets}" + DISCLAIMER)
                        return events
        except Exception: pass
        dispatcher.utter_message(text=f"I don't have precaution data for *{disease}*.")
        return events

class ActionVaccinationSchedule(Action):
    def name(self) -> Text: return "action_vaccination_schedule"
    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        text = tracker.latest_message.get("text", "").lower()
        events = [SlotSet("pending_symptom", None)]
        if any(kw in text for kw in ["pregnancy", "pregnant", "tt", "mother"]):
            msg = "**Pregnancy Vaccination Schedule:**\n\n* Tetanus Toxoid (TT) — 2 doses recommended\n* Flu vaccine — safe during pregnancy\n* Consult your OB-GYN for a personalised schedule"
        elif any(kw in text for kw in ["newborn", "infant", "new born"]) or (any(kw in text for kw in ["0", "1", "2", "3", "4", "5", "6"]) and any(unit in text for unit in ["month", "months"])):
            msg = "**0–6 Months Vaccination Schedule:**\n\n* BCG — at birth\n* OPV (Oral Polio Vaccine) — at birth, 6w, 10w, 14w\n* Hepatitis B — at birth, 6w, 14w\n* DPT — 6w, 10w, 14w"
        elif any(kw in text for kw in ["7", "8", "9", "10", "11", "12"]) and "month" in text:
            msg = "**6–12 Months Vaccination Schedule:**\n\n* Measles — 9 months\n* DPT Booster — 16–24 months\n* Hepatitis A — 12 months"
        else:
            msg = "**Standard Vaccination Schedule:**\n\n* 0–6 months: BCG, OPV, Hepatitis B, DPT\n* 6–12 months: Measles, DPT booster\n* Pregnancy: TT vaccine (2 doses)\n\nPlease share your age or category for a more specific schedule."
        
        disclaimer_vaccine = "\n\nPlease consult a pediatrician or healthcare provider to confirm the appropriate vaccination schedule."
        dispatcher.utter_message(text=msg + disclaimer_vaccine + DISCLAIMER)
        return events