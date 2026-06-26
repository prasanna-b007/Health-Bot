import csv

WEIGHTS_UPDATE = {
    "chest pain": 5, "breathlessness": 5, "coughing blood": 5, "face droop": 5, "slurred speech": 5, "loss of consciousness": 5, "vomiting blood": 5, "thunderclap headache": 5, "severe allergic reaction": 5,
    "severe abdominal pain": 4, "sudden vision loss": 4, "high fever": 4, "stiff neck": 4,
    "vomiting": 3, "nausea": 2, "fever": 2, "mild fever": 2, "headache": 1, "migraine": 3, "wheezing": 3,
    "cough": 2, "mild cough": 1, "diarrhoea": 2, "skin rash": 2, "burning micturition": 2, "itching": 1, "fatigue": 1, "runny nose": 1, "joint pain": 1
}

with open("datasets/Symptom-severity.csv", "r", encoding="utf-8") as f:
    rows = list(csv.reader(f))

with open("datasets/Symptom-severity.csv", "w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(rows[0])
    for row in rows[1:]:
        sym = row[0].strip().replace("_", " ").lower()
        if sym in WEIGHTS_UPDATE:
            row[1] = str(WEIGHTS_UPDATE[sym])
        elif int(row[1]) > 3: # downgrade generic 4s and 5s to 2 to avoid overtriage
            row[1] = "2"
        writer.writerow(row)

print("Weights updated successfully.")
