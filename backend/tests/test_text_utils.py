"""Symptom extraction from free text."""
import pytest

from actions import text_utils
from actions.normalize import normalize, normalize_disease, normalize_symptom


class TestNormalize:
    @pytest.mark.parametrize("raw,expected", [
        ("Skin_Rash", "skin rash"),
        ("  HIGH   FEVER  ", "high fever"),
        ("I can't breathe", "i cant breathe"),
        ("I can’t breathe", "i cant breathe"),
        ("Hypertension ", "hypertension"),
        (None, ""),
        ("", ""),
    ])
    def test_normalize(self, raw, expected):
        assert normalize(raw) == expected

    def test_csv_typos_are_repaired(self):
        # Symptom-severity.csv and dataset.csv spell these differently.
        assert normalize_symptom("foul_smell_ofurine") == "foul smell of urine"
        assert normalize_symptom("dischromic  patches") == "dischromic patches"

    def test_trailing_space_disease_names_collapse(self):
        assert normalize_disease("Hypertension ") == normalize_disease("Hypertension")


class TestAliases:
    def test_no_duplicate_canonical_keys(self):
        """Regression: 'high fever' was defined twice and the first won nothing.

        A literal dict cannot report duplicates at runtime, so this asserts on
        the source text -- which is the only place the mistake is visible.
        """
        import inspect
        import re

        source = inspect.getsource(text_utils)
        block = source.split("ALIASES: Dict[str, List[str]] = {", 1)[1]
        block = block.split("\n}\n", 1)[0]
        keys = re.findall(r'^\s{4}"([^"]+)":', block, re.MULTILINE)
        duplicates = {k for k in keys if keys.count(k) > 1}
        assert not duplicates, "duplicate alias keys silently overwrite: {}".format(duplicates)

    def test_every_alias_target_is_a_real_symptom(self, kb):
        assert text_utils.validate_aliases(kb.vocabulary) == []

    def test_fever_resolves_to_a_symptom(self, kb):
        """Regression: the duplicate key dropped 'fever' from the vocabulary."""
        assert text_utils.extract_symptoms("I have fever", kb.vocabulary) == ["high fever"]

    @pytest.mark.parametrize("phrase", [
        "temperature", "feverish", "running a fever", "high grade fever",
    ])
    def test_fever_synonyms_survive(self, kb, phrase):
        found = text_utils.extract_symptoms("I have {}".format(phrase), kb.vocabulary)
        assert "high fever" in found


class TestExtraction:
    def test_readme_example(self, kb):
        found = text_utils.extract_symptoms("I have fever and headache", kb.vocabulary)
        assert found == ["high fever", "headache"]

    def test_typos_are_corrected(self, kb):
        found = text_utils.extract_symptoms("high feaver and vomitting", kb.vocabulary)
        assert found == ["high fever", "vomiting"]

    def test_longer_phrase_wins_over_substring(self, kb):
        found = text_utils.extract_symptoms("I have chest pain", kb.vocabulary)
        assert found == ["chest pain"]

    def test_order_follows_the_text(self, kb):
        first = text_utils.extract_symptoms("headache then vomiting", kb.vocabulary)
        second = text_utils.extract_symptoms("vomiting then headache", kb.vocabulary)
        assert first == ["headache", "vomiting"]
        assert second == ["vomiting", "headache"]

    def test_unrecognised_text_yields_nothing(self, kb):
        assert text_utils.extract_symptoms("hello there", kb.vocabulary) == []

    def test_repeated_symptom_reported_once(self, kb):
        found = text_utils.extract_symptoms("headache, bad headache", kb.vocabulary)
        assert found == ["headache"]

    def test_extraction_is_deterministic(self, kb):
        text = "fever, headache, chills, nausea, joint pain"
        runs = {tuple(text_utils.extract_symptoms(text, kb.vocabulary)) for _ in range(10)}
        assert len(runs) == 1


class TestHelpers:
    @pytest.mark.parametrize("text,expected", [
        ("I am 42", 42), ("30", 30), ("no digits", None), ("", None), (None, None),
    ])
    def test_parse_number(self, text, expected):
        assert text_utils.parse_number(text) == expected

    def test_dedupe_preserves_order(self):
        assert text_utils.dedupe(["b", "a", "b", "c"]) == ["b", "a", "c"]

    def test_dedupe_normalises(self):
        assert text_utils.dedupe(["Skin_Rash", "skin rash"]) == ["skin rash"]
