"""Red-flag detection.

Under-triggering here is the failure that matters, so the cases below lean on
the phrasings a distressed user actually types.
"""
import pytest

from actions import emergency


class TestTextDetection:
    @pytest.mark.parametrize("text", [
        "I can't breathe",
        "I can’t breathe",
        "i cant breathe",
        "I cannot breathe",
        "CANNOT BREATHE",
        "I have chest pain",
        "my chest hurts really badly",
        "severe chest pain and I cannot breathe",
        "I think I'm having a heart attack",
        "he is unconscious",
        "she is coughing blood",
        "worst headache of life",
        "my throat is swelling",
    ])
    def test_red_flags_trigger(self, text):
        assert emergency.detect_in_text(text) is not None

    @pytest.mark.parametrize("text", [
        "I have a mild headache",
        "runny nose and sore throat",
        "I feel tired",
        "",
        None,
        "hello",
    ])
    def test_ordinary_complaints_do_not_trigger(self, text):
        assert emergency.detect_in_text(text) is None

    def test_apostrophe_regression(self):
        """The old matcher used \\b regex on raw text, so "can't" never matched.

        The action server's own regression script sent exactly this string.
        """
        assert emergency.detect_in_text("chest pain and I can't breathe") is not None


class TestSymptomDetection:
    def test_confirmed_red_flag_symptom_triggers(self):
        assert emergency.detect_in_symptoms(["high fever", "chest pain"]) == "chest pain"

    def test_ordinary_symptoms_do_not_trigger(self):
        assert emergency.detect_in_symptoms(["high fever", "headache"]) is None

    def test_underscored_form_still_matches(self):
        assert emergency.detect_in_symptoms(["chest_pain"]) == "chest pain"

    def test_empty_input(self):
        assert emergency.detect_in_symptoms([]) is None
        assert emergency.detect_in_symptoms(None) is None

    def test_red_flag_symptoms_exist_in_the_dataset(self, kb):
        """A red flag the dataset never uses can never be confirmed."""
        unknown = emergency.EMERGENCY_SYMPTOMS - kb.vocabulary
        assert not unknown, "red-flag symptoms absent from dataset.csv: {}".format(unknown)


class TestCombined:
    def test_detect_reads_both_sources(self):
        assert emergency.detect(text="hello", symptoms=["chest pain"]) == "chest pain"
        assert emergency.detect(text="I can't breathe", symptoms=[]) is not None
        assert emergency.detect(text="mild cough", symptoms=["headache"]) is None
