"""Free-text symptom extraction: aliases, typo correction, phrase matching.

Pure functions only -- no Rasa, no I/O beyond reading the knowledge base -- so
the whole extraction path is unit-testable without a running server.

This module also owns clause splitting and negation detection, because both
are text problems and both are needed in two places. emergency.py imports them
to avoid escalating "no chest pain", and extract_symptoms uses them for the
same reason in reverse: a user who writes "no chest pain, just a headache" was
previously recorded as having chest pain, which then drove the ranking, the
risk score and -- since chest pain is a red flag -- an emergency screen. The
negation logic existed in the detector and nowhere else, so the detector
declined to escalate a symptom the extractor had already confirmed.
"""
import difflib
import logging
import re
from typing import Dict, Iterable, List, Optional, Set, Tuple

from .normalize import normalize, normalize_symptom

logger = logging.getLogger(__name__)

# Words that, appearing before a phrase in the same clause, mean the user is
# telling us it does NOT apply. "cant" is absent on purpose: it is a negator in
# English and also the first half of "cant breathe", and checking only the text
# *before* a match is what keeps the two apart.
NEGATORS = {
    "no", "not", "dont", "doesnt", "didnt", "isnt", "arent", "wasnt",
    "havent", "hasnt", "hadnt", "never", "without", "denies", "deny", "denied",
}

# Clause boundaries. Splitting first means a negation in one clause cannot
# reach into the next: in "no fever but severe chest pain" the chest pain is
# not negated, and treating it as though it were would be the worst kind of
# mistake this codebase can make.
_CLAUSE_SPLIT = re.compile(
    r"[,.;:!?]+|\s+(?:but|however|although|though|and|or|while|whereas)\s+"
)

_WORD = re.compile(r"[a-z0-9]+")


def clause_spans(text: str) -> List[Tuple[int, int]]:
    """Character ranges of each clause in already-normalised text."""
    spans: List[Tuple[int, int]] = []
    start = 0
    for boundary in _CLAUSE_SPLIT.finditer(text):
        if boundary.start() > start:
            spans.append((start, boundary.start()))
        start = boundary.end()
    if start < len(text):
        spans.append((start, len(text)))
    return spans


def clauses(text: str) -> List[str]:
    return [text[start:end].strip() for start, end in clause_spans(text)]


def is_negated(text: str, index: int) -> bool:
    """True if the phrase at `index` is negated within its own clause."""
    for start, end in clause_spans(text):
        if start <= index < end:
            return any(word in NEGATORS for word in _WORD.findall(text[start:index]))
    return False

# Everyday phrasings mapped onto the canonical symptom names used by
# dataset.csv. Each canonical key appears EXACTLY ONCE -- an earlier version
# defined "high fever" twice, and the second definition silently deleted the
# first, dropping "fever", "temperature" and "feverish" from the vocabulary.
ALIASES: Dict[str, List[str]] = {
    "high fever": [
        "fever", "mild fever", "high temperature", "temperature", "feverish",
        "feeling hot", "feaver", "tempature", "running a fever",
        "very high fever", "high grade fever", "severe fever", "high feaver",
    ],
    "headache": ["head pain", "head ache", "head is pounding", "migraine", "headake"],
    "skin rash": [
        "rash", "rashes", "rash on skin", "body rash", "rashes on body",
        "skin eruptions",
    ],
    "itching": ["itchy skin", "skin itch", "itchy"],
    "burning micturition": [
        "burning sensation while urinating", "burning while peeing",
        "burning urination", "pain while urinating", "burning when i urinate",
        "it burns when i pee", "painful urination",
    ],
    "fatigue": [
        "tiredness", "tired all the time", "always tired", "feeling tired",
        "no energy", "weakness", "feeling weak", "exhausted",
    ],
    "vomiting": ["throwing up", "puking", "vomit"],
    "nausea": ["nauseous", "feel like vomiting", "want to vomit", "queasy"],
    "cough": ["coughing", "continuous cough", "persistent cough"],
    "chest pain": ["chest tightness", "pain in chest", "chest hurts", "pressure in chest"],
    "breathlessness": [
        "shortness of breath", "difficulty breathing", "cant breathe",
        "cannot breathe", "hard to breathe", "breathless", "breathing difficulty",
    ],
    "dizziness": ["dizzy", "feeling dizzy", "light headed", "lightheaded", "spinning"],
    "joint pain": ["joints hurt", "joint ache", "joints aching", "joint swelling"],
    "back pain": ["pain in back", "backache", "lower back pain"],
    "stomach pain": [
        "abdominal pain", "stomach ache", "tummy ache", "pain in stomach",
        "belly pain",
    ],
    "diarrhoea": ["diarrhea", "loose stools", "loose motion", "watery stool"],
    "sweating": ["excessive sweating", "night sweats", "profuse sweating"],
    "weight loss": ["losing weight", "lost weight", "weight has reduced"],
    "yellowing of eyes": ["yellow eyes", "jaundice eyes", "yellow skin and eyes"],
    "chills": ["shivering", "cold chills", "feeling cold"],
    "loss of appetite": ["no appetite", "not feeling hungry", "cant eat"],
    "muscle pain": ["muscle ache", "body ache", "body pain", "myalgia"],
    "neck pain": ["stiff neck", "pain in neck"],
    "blurred and distorted vision": [
        "blurred vision", "blurry vision", "vision is blurry", "cant see clearly",
    ],
    "runny nose": ["running nose", "watery nose", "nose is running"],

    # --- Everything below closes a gap the evaluation suite exposed. -------
    # The table above covered 25 of the knowledge base's 131 symptoms, so a
    # user writing "my joints are swollen and walking hurts" -- three real
    # symptoms of arthritis in plain English -- was told the bot could not
    # understand them. Canonical names still match on their own; these are the
    # phrasings people actually type instead.
    "throat irritation": [
        "sore throat", "throat hurts", "scratchy throat", "throat pain",
        "painful throat", "irritated throat",
    ],
    "continuous sneezing": [
        "sneezing", "sneezing a lot", "keep sneezing", "cant stop sneezing",
        "constant sneezing", "sneezes",
    ],
    "congestion": [
        "blocked nose", "stuffy nose", "nose is blocked", "nasal congestion",
        "cant breathe through my nose",
    ],
    "sinus pressure": ["sinus pain", "pressure in my sinuses", "sinuses hurt"],
    "phlegm": ["mucus", "bringing up phlegm", "chest congestion", "catarrh"],
    "mucoid sputum": ["thick mucus", "sputum", "mucus when i cough"],
    "rusty sputum": ["rust coloured sputum", "brown sputum", "blood tinged sputum"],
    "swelling joints": [
        "swollen joints", "joints are swollen", "joint swelling", "puffy joints",
    ],
    "movement stiffness": [
        "stiffness", "stiff when i move", "stiff joints", "stiffness moving",
        "joints are stiff", "stiff in the morning",
    ],
    "painful walking": [
        "hurts to walk", "walking hurts", "pain when walking", "difficulty walking",
        "cant walk properly",
    ],
    "muscle weakness": ["weak muscles", "muscles feel weak", "lost strength"],
    "weakness in limbs": [
        "weak arms", "weak legs", "arms feel weak", "legs feel weak",
        "limbs are weak", "weakness in my arms",
    ],
    "weakness of one body side": [
        "one side feels weak", "one side is weak", "weakness on one side",
        "left side is weak", "right side is weak", "half my body is weak",
    ],
    "slurred speech": [
        "speech is slurred", "slurring my words", "words are slurred",
        "cant speak clearly", "speech is unclear",
    ],
    "stiff neck": ["neck is stiff", "cant turn my neck"],
    "knee pain": ["knee hurts", "pain in my knee", "sore knee", "knees hurt"],
    "hip joint pain": ["hip pain", "hip hurts", "pain in my hip"],
    "abdominal pain": ["pain in my abdomen", "abdomen hurts", "cramping in my abdomen"],
    "belly pain": ["belly hurts", "lower belly pain", "pain in my belly"],
    "acidity": [
        "acid reflux", "heartburn", "burning in my chest after eating",
        "acid coming up", "reflux", "sour taste",
    ],
    "indigestion": ["cant digest", "upset stomach", "dyspepsia", "bloated after eating"],
    "constipation": [
        "cant pass stool", "hard stools", "not been to the toilet",
        "difficulty passing stool", "constipated",
    ],
    "passage of gases": ["gas", "passing gas", "flatulence", "farting a lot"],
    "bloody stool": [
        "blood in stool", "blood when i pass stool", "bleeding when i poop",
        "blood in my poo", "rectal bleeding", "bleeding when i pass stool",
        "bleeding from my bottom", "blood when i go to the toilet",
    ],
    "pain during bowel movements": [
        "hurts to pass stool", "pain when passing stool", "painful bowel movement",
    ],
    "pain in anal region": [
        "anal pain", "pain near my anus", "bottom hurts",
        "pain in the anal region", "pain around my anus",
    ],
    "irritation in anus": ["itchy anus", "anal itching", "irritation near anus"],
    "dehydration": ["dehydrated", "very thirsty", "cant keep fluids down"],
    "sunken eyes": ["eyes look sunken", "hollow eyes"],
    "distention of abdomen": ["bloated", "bloating", "swollen abdomen", "abdomen is swollen"],
    "swelling of stomach": ["stomach is swollen", "swollen stomach"],
    "ulcers on tongue": ["mouth ulcers", "sores on my tongue", "tongue ulcers"],
    "patches in throat": ["white patches in throat", "spots in my throat"],
    "loss of smell": ["cant smell", "lost my sense of smell", "no sense of smell"],
    "excessive hunger": ["always hungry", "constantly hungry", "hungry all the time"],
    "increased appetite": ["eating more than usual", "appetite has increased"],
    "polyuria": [
        "peeing a lot", "urinating frequently", "urinating a lot",
        "passing urine often", "frequent urination", "going to the toilet a lot",
    ],
    "continuous feel of urine": [
        "always need to pee", "feel like i need to urinate", "constant urge to pee",
        "keep needing to go", "urge to urinate",
    ],
    "bladder discomfort": ["bladder pain", "discomfort in my bladder"],
    "foul smell of urine": [
        "smelly urine", "urine smells bad", "bad smelling pee", "strong smelling urine",
    ],
    "dark urine": ["urine is dark", "dark coloured pee", "brown urine"],
    "yellow urine": ["yellow pee", "urine looks yellow"],
    "spotting urination": ["spotting when i urinate", "blood spots in urine"],
    "yellowish skin": [
        "yellow skin", "skin looks yellow", "turning yellow", "jaundiced skin",
    ],
    "red spots over body": [
        "red spots", "spots all over my body", "red dots on skin", "spots on my body",
    ],
    "skin peeling": [
        "peeling skin", "skin is peeling", "flaking skin", "scaly skin",
        "patches on my skin that peel", "skin that peels", "scaly patches",
    ],
    "silver like dusting": [
        "silvery scales", "silver scales", "scaly silver patches",
        "silvery scaly patches", "silvery patches", "silver coloured patches",
    ],
    "small dents in nails": [
        "pitted nails", "dents in my nails", "nail pitting",
        "nails are pitted", "pits in my nails",
    ],
    "inflammatory nails": ["inflamed nails", "sore nails", "nails are swollen"],
    "brittle nails": ["nails break easily", "weak nails", "nails are brittle"],
    "blister": ["blisters", "blistering", "water filled bumps"],
    "red sore around nose": ["sores around my nose", "red sore near my nose"],
    "yellow crust ooze": ["yellow crust", "crusty ooze", "oozing yellow"],
    "pus filled pimples": ["pus filled spots", "pimples with pus", "infected pimples"],
    "blackheads": ["black heads", "clogged pores"],
    "swelled lymph nodes": [
        "swollen glands", "swollen lymph nodes", "lumps in my neck", "glands are up",
    ],
    "redness of eyes": ["red eyes", "eyes are red", "bloodshot eyes"],
    "watering from eyes": ["watery eyes", "eyes are watering", "streaming eyes"],
    "pain behind the eyes": [
        "pain behind my eyes", "eyes hurt", "aching behind the eyes",
        "pressure behind my eyes",
    ],
    "visual disturbances": ["seeing spots", "flashing lights", "vision problems"],
    "loss of balance": [
        "losing my balance", "unbalanced", "cant keep my balance", "off balance",
    ],
    "unsteadiness": ["unsteady", "wobbly", "unsteady on my feet"],
    "spinning movements": ["room is spinning", "everything is spinning", "vertigo"],
    "palpitations": [
        "heart racing", "heart pounding", "racing heartbeat", "fluttering heart",
    ],
    "fast heart rate": ["rapid heartbeat", "heart beating fast", "high pulse"],
    "restlessness": ["restless", "cant sit still", "feeling restless"],
    "anxiety": ["anxious", "feeling anxious", "panicky", "on edge"],
    "depression": ["depressed", "feeling low", "very low mood", "hopeless"],
    "mood swings": ["moods change quickly", "mood is all over the place", "moody"],
    "irritability": ["irritable", "short tempered", "snapping at people"],
    "lack of concentration": [
        "cant concentrate", "trouble focusing", "cant focus", "poor concentration",
    ],
    "lethargy": ["sluggish", "lethargic", "no motivation", "heavy and slow"],
    "malaise": ["feeling unwell", "generally unwell", "feel rough", "under the weather"],
    "mild fever": ["slight fever", "low grade fever", "a bit feverish"],
    "weight gain": ["gaining weight", "put on weight", "weight has increased"],
    "obesity": ["overweight", "obese"],
    "muscle wasting": ["losing muscle", "muscles are wasting", "muscle loss"],
    "cold hands and feets": [
        "cold hands", "cold feet", "hands and feet are always cold",
    ],
    "swollen extremeties": ["swollen hands", "swollen feet", "puffy hands and feet"],
    "swollen legs": ["legs are swollen", "swelling in my legs", "puffy legs"],
    "swollen blood vessels": ["bulging veins", "swollen veins"],
    "prominent veins on calf": [
        "veins on my calf", "visible veins on my legs", "veins sticking out",
    ],
    "cramps": ["cramping", "muscle cramps", "leg cramps"],
    "bruising": ["bruises", "bruising easily", "bruise easily"],
    "puffy face and eyes": ["puffy face", "swollen face", "face is puffy"],
    "enlarged thyroid": ["swollen thyroid", "lump in my throat", "goitre", "goiter"],
    "drying and tingling lips": ["tingling lips", "dry lips", "lips tingle"],
    "altered sensorium": ["confused", "confusion", "disoriented", "not making sense"],
    "blood in sputum": ["coughing up blood", "blood when i cough", "blood in my phlegm"],
    "irregular sugar level": ["blood sugar is erratic", "sugar levels are irregular"],
    "family history": ["runs in my family", "family history"],
    "internal itching": ["itching inside", "internal itch"],
    "scurring": ["scarring", "scars on my skin"],
    "dischromic patches": [
        "discoloured patches", "discolored patches", "patches of different colour",
    ],
    "nodal skin eruptions": ["lumps on my skin", "skin nodules", "raised bumps"],
}

_MIN_TYPO_LENGTH = 4
_TYPO_CUTOFF = 0.8


def validate_aliases(vocabulary: Iterable[str]) -> List[str]:
    """Return alias keys that are not real symptoms, logging a warning for each.

    A canonical key that is not in the dataset silently matches nothing, which
    is exactly the failure mode this function exists to surface.
    """
    vocab = set(vocabulary)
    unknown = sorted(key for key in ALIASES if key not in vocab)
    if unknown:
        logger.warning(
            "%d alias target(s) are not symptoms in dataset.csv and will never "
            "match: %s", len(unknown), ", ".join(unknown),
        )
    return unknown


def _alias_lookup() -> Dict[str, str]:
    """Flat {phrase -> canonical symptom} map, including the canonical names."""
    lookup: Dict[str, str] = {}
    for canonical, synonyms in ALIASES.items():
        lookup[canonical] = canonical
        for synonym in synonyms:
            lookup[normalize(synonym)] = canonical
    return lookup


_ALIAS_LOOKUP = _alias_lookup()


def _single_word_terms(vocabulary: Iterable[str]) -> Set[str]:
    """Every word autocorrect is allowed to produce, or must leave alone.

    Both halves matter. The first set is the repair target: single-word
    symptoms and single-word aliases are what a typo can be corrected *to*.
    The second is protection, and it was missing. Autocorrect ran over the raw
    text before any phrase matching, so a word appearing only inside a
    multi-word alias looked unknown and got "repaired" into something else --
    "it burns when I pee and I keep needing to go" became "...keep sneezing to
    go", which destroyed the urinary alias it was about to match and handed
    the ranker a respiratory symptom instead. Every word of every alias phrase
    is therefore known, and only genuinely foreign words are candidates for
    correction.
    """
    terms = {term for term in vocabulary if " " not in term}
    terms.update(phrase for phrase in _ALIAS_LOOKUP if " " not in phrase)
    return terms


def _protected_words(vocabulary: Iterable[str]) -> Set[str]:
    """Words that appear in any known symptom or alias phrase."""
    words: Set[str] = set()
    for phrase in vocabulary:
        words.update(_WORD.findall(phrase))
    for phrase in _ALIAS_LOOKUP:
        words.update(_WORD.findall(phrase))
    return words


def autocorrect(text: str, vocabulary: Iterable[str]) -> str:
    """Repair single-word typos against the known symptom vocabulary."""
    known = _single_word_terms(vocabulary)
    protected = _protected_words(vocabulary)
    corrected: List[str] = []
    for word in normalize(text).split():
        stripped = re.sub(r"[^\w\s]", "", word)
        if (
            len(stripped) >= _MIN_TYPO_LENGTH
            and stripped not in known
            and stripped not in protected
        ):
            match = difflib.get_close_matches(stripped, known, n=1, cutoff=_TYPO_CUTOFF)
            if match:
                corrected.append(match[0])
                continue
        corrected.append(word)
    return " ".join(corrected)


def extract_symptoms(
    text: str, vocabulary: Iterable[str], include_negated: bool = False
) -> List[str]:
    """Find canonical symptoms in free text, in order of first appearance.

    Longer phrases are matched first and their span consumed, so "chest pain"
    is never also reported as a bare "pain" match. Results are ordered by
    position in the text rather than by iteration over a set, which keeps the
    same input producing the same output across processes.

    Symptoms the user explicitly denies are skipped. "No chest pain, just a
    headache" used to confirm chest pain -- which ranked the user against
    cardiac conditions, raised their risk score, and tripped the red-flag
    detector that had carefully declined to escalate the same sentence.
    Pass include_negated=True to see what was filtered; negated_symptoms()
    is the direct way to ask.
    """
    vocab = set(vocabulary)
    corrected = autocorrect(text, vocab)

    # {phrase -> canonical}: real symptom names plus every alias phrase.
    phrases: Dict[str, str] = {term: term for term in vocab}
    for phrase, canonical in _ALIAS_LOOKUP.items():
        if canonical in vocab:
            phrases.setdefault(phrase, canonical)

    consumed = [False] * len(corrected)
    hits: List[tuple] = []
    for phrase in sorted(phrases, key=len, reverse=True):
        for match in re.finditer(r"\b" + re.escape(phrase) + r"\b", corrected):
            start, end = match.span()
            if any(consumed[start:end]):
                continue
            for index in range(start, end):
                consumed[index] = True
            negated = is_negated(corrected, start)
            if negated and not include_negated:
                continue
            hits.append((start, phrases[phrase]))

    found: List[str] = []
    for _, canonical in sorted(hits):
        if canonical not in found:
            found.append(canonical)
    return found


def negated_symptoms(text: str, vocabulary: Iterable[str]) -> List[str]:
    """Symptoms the user mentioned in order to rule them out.

    Worth having separately: "no chest pain" is real evidence, not noise, and
    the scorer treats a denial as information. Callers may feed these straight
    into TriageState.deny.
    """
    everything = extract_symptoms(text, vocabulary, include_negated=True)
    confirmed = set(extract_symptoms(text, vocabulary))
    return [symptom for symptom in everything if symptom not in confirmed]


def parse_number(text: str) -> Optional[int]:
    """First integer in the text, or None."""
    match = re.search(r"\d+", text or "")
    return int(match.group()) if match else None


def dedupe(items: Iterable[str]) -> List[str]:
    """Order-preserving dedupe.

    Used instead of set() wherever the result reaches the user: Python
    randomises string hashing per process, so set ordering made identical
    sessions produce different question order across server restarts.
    """
    seen: Set[str] = set()
    out: List[str] = []
    for item in items:
        key = normalize_symptom(item)
        if key and key not in seen:
            seen.add(key)
            out.append(key)
    return out
