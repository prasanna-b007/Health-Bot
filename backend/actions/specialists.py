"""Specialist referral for each condition in dataset.csv.

Keys are canonical disease names (see normalize.normalize_disease), so the
lookup no longer needs one entry per spelling -- the previous map carried
"Hypertension " and "Diabetes " with trailing spaces purely to match unclean
CSV values, which normalisation at load time now handles.
"""
from typing import Dict

from .normalize import normalize_disease

DEFAULT_SPECIALIST: Dict[str, str] = {'name': 'General Physician', 'description': 'A general physician can assess your condition and refer you to the right specialist.', 'icon': 'general', 'priority': 'Routine', 'department': 'General Medicine'}

SPECIALISTS: Dict[str, Dict[str, str]] = {
    '(vertigo) paroymsal positional vertigo': {
        'name': 'Neurologist',
        'description': 'Specialist in balance and nervous system disorders.',
        'icon': 'brain',
        'priority': 'Soon',
        'department': 'Neurology',
    },
    'acne': {
        'name': 'Dermatologist',
        'description': 'Specialist in skin conditions and acne treatment.',
        'icon': 'skin',
        'priority': 'Routine',
        'department': 'Dermatology',
    },
    'aids': {
        'name': 'Infectious Disease Specialist',
        'description': 'Specialist in HIV/AIDS and immune system conditions.',
        'icon': 'immune',
        'priority': 'Immediate',
        'department': 'Infectious Diseases',
    },
    'alcoholic hepatitis': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver conditions and digestive health.',
        'icon': 'stomach',
        'priority': 'Immediate',
        'department': 'Gastroenterology',
    },
    'allergy': {
        'name': 'Allergist / Immunologist',
        'description': 'Specialist in allergic reactions and immune system conditions.',
        'icon': 'immune',
        'priority': 'Soon',
        'department': 'Allergy & Immunology',
    },
    'arthritis': {
        'name': 'Rheumatologist',
        'description': 'Specialist in joint and autoimmune conditions.',
        'icon': 'bone',
        'priority': 'Soon',
        'department': 'Rheumatology',
    },
    'bronchial asthma': {
        'name': 'Pulmonologist',
        'description': 'Specialist in lung and respiratory diseases.',
        'icon': 'lungs',
        'priority': 'Soon',
        'department': 'Pulmonology',
    },
    'cervical spondylosis': {
        'name': 'Orthopedic Surgeon',
        'description': 'Specialist in spine, bone, and joint conditions.',
        'icon': 'bone',
        'priority': 'Routine',
        'department': 'Orthopedics',
    },
    'chicken pox': {
        'name': 'General Physician',
        'description': 'A general physician manages chickenpox and viral infections.',
        'icon': 'virus',
        'priority': 'Routine',
        'department': 'General Medicine',
    },
    'chronic cholestasis': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver and digestive system conditions.',
        'icon': 'stomach',
        'priority': 'Soon',
        'department': 'Gastroenterology',
    },
    'common cold': {
        'name': 'General Physician',
        'description': 'A general physician manages common viral infections.',
        'icon': 'general',
        'priority': 'Routine',
        'department': 'General Medicine',
    },
    'dengue': {
        'name': 'General Physician',
        'description': 'A general physician manages dengue and common infections.',
        'icon': 'virus',
        'priority': 'Immediate',
        'department': 'General Medicine',
    },
    'diabetes': {
        'name': 'Endocrinologist',
        'description': 'Specialist in hormone and metabolic conditions including diabetes.',
        'icon': 'metabolism',
        'priority': 'Soon',
        'department': 'Endocrinology',
    },
    'dimorphic hemmorhoids(piles)': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in digestive and colorectal conditions.',
        'icon': 'stomach',
        'priority': 'Routine',
        'department': 'Gastroenterology',
    },
    'drug reaction': {
        'name': 'General Physician',
        'description': 'A general physician manages drug reactions and medication issues.',
        'icon': 'general',
        'priority': 'Immediate',
        'department': 'General Medicine',
    },
    'fungal infection': {
        'name': 'Dermatologist',
        'description': 'Specialist in skin, nail, and fungal conditions.',
        'icon': 'skin',
        'priority': 'Routine',
        'department': 'Dermatology',
    },
    'gastroenteritis': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in digestive and stomach conditions.',
        'icon': 'stomach',
        'priority': 'Soon',
        'department': 'Gastroenterology',
    },
    'gerd': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in digestive and acid reflux conditions.',
        'icon': 'stomach',
        'priority': 'Routine',
        'department': 'Gastroenterology',
    },
    'heart attack': {
        'name': 'Cardiologist',
        'description': 'Specialist in heart and cardiovascular conditions.',
        'icon': 'heart',
        'priority': 'Immediate',
        'department': 'Cardiology',
    },
    'hepatitis a': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver infections and digestive conditions.',
        'icon': 'stomach',
        'priority': 'Soon',
        'department': 'Gastroenterology',
    },
    'hepatitis b': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver infections and digestive conditions.',
        'icon': 'stomach',
        'priority': 'Immediate',
        'department': 'Gastroenterology',
    },
    'hepatitis c': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver infections and digestive conditions.',
        'icon': 'stomach',
        'priority': 'Immediate',
        'department': 'Gastroenterology',
    },
    'hepatitis d': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver infections and digestive conditions.',
        'icon': 'stomach',
        'priority': 'Immediate',
        'department': 'Gastroenterology',
    },
    'hepatitis e': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver infections and digestive conditions.',
        'icon': 'stomach',
        'priority': 'Soon',
        'department': 'Gastroenterology',
    },
    'hypertension': {
        'name': 'Cardiologist',
        'description': 'Specialist in heart and blood pressure conditions.',
        'icon': 'heart',
        'priority': 'Soon',
        'department': 'Cardiology',
    },
    'hyperthyroidism': {
        'name': 'Endocrinologist',
        'description': 'Specialist in thyroid and hormone conditions.',
        'icon': 'metabolism',
        'priority': 'Soon',
        'department': 'Endocrinology',
    },
    'hypoglycemia': {
        'name': 'Endocrinologist',
        'description': 'Specialist in blood sugar and metabolic conditions.',
        'icon': 'metabolism',
        'priority': 'Immediate',
        'department': 'Endocrinology',
    },
    'hypothyroidism': {
        'name': 'Endocrinologist',
        'description': 'Specialist in thyroid and hormone conditions.',
        'icon': 'metabolism',
        'priority': 'Routine',
        'department': 'Endocrinology',
    },
    'impetigo': {
        'name': 'Dermatologist',
        'description': 'Specialist in skin infections.',
        'icon': 'skin',
        'priority': 'Soon',
        'department': 'Dermatology',
    },
    'jaundice': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in liver and digestive system conditions.',
        'icon': 'stomach',
        'priority': 'Soon',
        'department': 'Gastroenterology',
    },
    'malaria': {
        'name': 'General Physician',
        'description': 'A general physician manages malaria and tropical infections.',
        'icon': 'virus',
        'priority': 'Immediate',
        'department': 'General Medicine',
    },
    'migraine': {
        'name': 'Neurologist',
        'description': 'Specialist in brain and nervous system disorders.',
        'icon': 'brain',
        'priority': 'Soon',
        'department': 'Neurology',
    },
    'osteoarthristis': {
        'name': 'Orthopedic Surgeon',
        'description': 'Specialist in bone and joint conditions.',
        'icon': 'bone',
        'priority': 'Routine',
        'department': 'Orthopedics',
    },
    'paralysis (brain hemorrhage)': {
        'name': 'Neurologist',
        'description': 'Specialist in brain and nervous system conditions.',
        'icon': 'brain',
        'priority': 'Immediate',
        'department': 'Neurology',
    },
    'peptic ulcer diseae': {
        'name': 'Gastroenterologist',
        'description': 'Specialist in digestive and stomach conditions.',
        'icon': 'stomach',
        'priority': 'Soon',
        'department': 'Gastroenterology',
    },
    'pneumonia': {
        'name': 'Pulmonologist',
        'description': 'Specialist in lung and respiratory diseases.',
        'icon': 'lungs',
        'priority': 'Immediate',
        'department': 'Pulmonology',
    },
    'psoriasis': {
        'name': 'Dermatologist',
        'description': 'Specialist in chronic skin conditions.',
        'icon': 'skin',
        'priority': 'Routine',
        'department': 'Dermatology',
    },
    'tuberculosis': {
        'name': 'Pulmonologist',
        'description': 'Specialist in lung and respiratory diseases.',
        'icon': 'lungs',
        'priority': 'Immediate',
        'department': 'Pulmonology',
    },
    'typhoid': {
        'name': 'General Physician',
        'description': 'A general physician manages typhoid and bacterial infections.',
        'icon': 'virus',
        'priority': 'Soon',
        'department': 'General Medicine',
    },
    'urinary tract infection': {
        'name': 'Urologist',
        'description': 'Specialist in urinary tract and kidney conditions.',
        'icon': 'kidney',
        'priority': 'Soon',
        'department': 'Urology',
    },
    'varicose veins': {
        'name': 'Vascular Surgeon',
        'description': 'Specialist in vein and blood vessel conditions.',
        'icon': 'blood',
        'priority': 'Routine',
        'department': 'Vascular Surgery',
    },
}


def get_specialist(disease: str) -> Dict[str, str]:
    """Referral details for a disease, falling back to a general physician."""
    return SPECIALISTS.get(normalize_disease(disease), DEFAULT_SPECIALIST)
