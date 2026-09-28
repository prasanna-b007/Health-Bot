"""Knowledge base loading, normalisation and validation."""
import pytest

from actions import datastore, specialists
from actions.normalize import normalize_disease


class TestLoading:
    def test_all_diseases_load(self, kb):
        assert len(kb.disease_symptoms) == 41

    def test_case_rows_are_counted(self, kb):
        """Every CSV row is counted, and duplicates are counted separately."""
        assert sum(kb.case_rows.values()) == 4920
        assert all(count > 0 for count in kb.case_rows.values())

    def test_presentations_collapse_duplicate_rows(self, kb):
        """dataset.csv pads each condition to 120 rows by permuting a handful
        of symptom sets. Scoring counts the distinct sets, because the
        duplicates are not independent observations and counting them made a
        five-pattern condition look like a 120-case study."""
        assert kb.disease_rows["fungal infection"] == 5
        assert kb.case_rows["fungal infection"] == 120
        total_distinct = sum(kb.disease_rows.values())
        assert total_distinct < sum(kb.case_rows.values())
        assert all(
            kb.disease_rows[d] <= kb.case_rows[d] for d in kb.disease_rows
        )

    def test_base_rates_are_probabilities(self, kb):
        assert kb.symptom_base_rate
        assert all(0.0 < rate <= 1.0 for rate in kb.symptom_base_rate.values())
        # A symptom shared by many conditions must not look distinctive.
        assert kb.base_rate_of("fatigue") > kb.base_rate_of("rusty sputum")

    def test_keys_are_canonical(self, kb):
        for disease in kb.disease_symptoms:
            assert disease == normalize_disease(disease)
        for symptom in kb.vocabulary:
            assert symptom == symptom.strip().lower()
            assert "_" not in symptom
            assert "  " not in symptom

    def test_label_column_is_not_a_symptom(self, kb):
        """Symptom-severity.csv contains a 'prognosis' row that is a label."""
        assert "prognosis" not in kb.vocabulary
        assert "prognosis" not in kb.severity

    def test_loading_is_cached(self):
        assert datastore.load() is datastore.load()

    def test_every_dataset_symptom_has_a_severity_weight(self, kb):
        missing = kb.vocabulary - set(kb.severity)
        assert not missing, "no severity weight for: {}".format(sorted(missing))


class TestFailureIsLoud:
    def test_missing_file_raises(self, monkeypatch):
        """Regression: every loader caught all exceptions and returned empty,
        so a missing CSV surfaced as an unhelpful conversational dead end."""
        monkeypatch.setattr(datastore, "DATASET_PATH", "does-not-exist.csv")
        with pytest.raises(datastore.DatasetError):
            datastore.load(force=True)

    def test_error_names_the_file(self, monkeypatch):
        monkeypatch.setattr(datastore, "SEVERITY_PATH", "missing-severity.csv")
        with pytest.raises(datastore.DatasetError, match="missing-severity.csv"):
            datastore.load(force=True)


class TestAdvice:
    def test_advice_is_per_disease(self, kb):
        assert kb.advice_for("Dengue") != kb.advice_for("Fungal infection")

    def test_general_advice_is_always_appended(self, kb):
        for disease in kb.disease_symptoms:
            advice = kb.advice_for(disease)
            for item in datastore.GENERAL_ADVICE:
                assert item in advice

    def test_unknown_disease_falls_back_to_general(self, kb):
        assert kb.advice_for("not a real disease") == datastore.GENERAL_ADVICE

    def test_advice_entries_are_capitalised(self, kb):
        for disease in kb.disease_symptoms:
            for item in kb.advice_for(disease):
                assert item[0].isupper()


class TestLookups:
    def test_severity_defaults_to_one(self, kb):
        assert kb.severity_of("not a symptom") == 1

    def test_max_severity_of_empty_list(self, kb):
        assert kb.max_severity([]) == 1

    def test_severity_accepts_any_spelling(self, kb):
        assert kb.severity_of("chest_pain") == kb.severity_of("Chest Pain")

    def test_description_lookup_tolerates_dirty_names(self, kb):
        assert kb.description_of("Hypertension ") == kb.description_of("hypertension")


class TestSpecialists:
    def test_every_disease_has_a_specialist(self, kb):
        for disease in kb.disease_symptoms:
            assert specialists.get_specialist(disease) is not specialists.DEFAULT_SPECIALIST

    def test_no_duplicate_entries_from_dirty_keys(self):
        """Regression: the map carried "Hypertension " and "Diabetes " with
        trailing spaces purely to match unclean CSV values."""
        assert len(specialists.SPECIALISTS) == 41
        assert all(key == normalize_disease(key) for key in specialists.SPECIALISTS)

    def test_unknown_disease_gets_a_general_physician(self):
        assert specialists.get_specialist("nonsense") == specialists.DEFAULT_SPECIALIST

    def test_entries_are_complete(self):
        for disease, entry in specialists.SPECIALISTS.items():
            for field in ("name", "description", "icon", "priority", "department"):
                assert entry.get(field), "{} is missing {}".format(disease, field)
            assert entry["priority"] in {"Immediate", "Soon", "Routine"}
