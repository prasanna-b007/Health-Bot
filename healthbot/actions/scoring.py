from typing import List, Dict, Tuple

SYMPTOM_WEIGHTS = {
    "chest pain": 3.0,
    "severe chest pain": 3.0,
    "shortness of breath": 3.0,
    "severe bleeding": 3.0,
    "unconsciousness": 3.0,
    "high fever": 2.0,
    "vomiting": 2.0,
    "fatigue": 1.0,
    "headache": 1.0,
    "cough": 1.0,
}

def get_weight(symptom: str) -> float:
    return SYMPTOM_WEIGHTS.get(symptom.lower().replace("_", " "), 1.0)

def calculate_weighted_match_scores(confirmed: List[str], disease_map: Dict[str, List[str]]) -> List[Tuple[str, float]]:
    scores = []
    for disease, symps in disease_map.items():
        total_weight = sum(get_weight(s) for s in symps)
        if total_weight == 0:
            continue
            
        matched_symps = [s for s in confirmed if s in symps]
        matched_weight = sum(get_weight(s) for s in matched_symps)
        
        pct = (matched_weight / total_weight) * 100.0 if total_weight > 0 else 0.0
        
        # Boosts
        if disease == "pneumonia":
            if "fever" in matched_symps and "cough" in matched_symps and "chest pain" in matched_symps:
                pct *= 1.2
                
        # Penalties
        if disease == "tuberculosis":
            if "weight loss" not in matched_symps:
                pct *= 0.8
                
        if pct > 0:
            scores.append((disease, min(pct, 100.0)))
            
    scores.sort(key=lambda x: x[1], reverse=True)
    return scores
