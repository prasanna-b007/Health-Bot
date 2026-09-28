"""Disease ranking."""
import pytest

from actions import scoring


class TestRanking:
    def test_distinctive_symptoms_identify_a_condition(self, kb):
        scores = scoring.rank(kb, ["itching", "skin rash", "nodal skin eruptions"])
        assert scores[0].disease == "fungal infection"
        # Was > 0.9 before the model was calibrated. Counting distinct
        # presentations rather than padded rows, discounting correlated
        # evidence and letting "unspecified illness" compete all pull the
        # posterior down, and all three were corrections of overconfidence
        # rather than losses of accuracy: the condition still leads, clearly.
        assert scores[0].probability > 0.5

    def test_probabilities_form_a_distribution(self, kb):
        scores = scoring.rank(kb, ["high fever", "headache"])
        assert pytest.approx(sum(s.probability for s in scores), abs=1e-6) == 1.0
        assert all(0.0 <= s.probability <= 1.0 for s in scores)

    def test_no_evidence_yields_no_ranking(self, kb):
        assert scoring.rank(kb, []) == []

    def test_results_are_sorted_by_probability(self, kb):
        scores = scoring.rank(kb, ["high fever", "chills", "nausea"])
        probabilities = [s.probability for s in scores]
        assert probabilities == sorted(probabilities, reverse=True)

    def test_ranking_is_deterministic(self, kb):
        runs = {
            tuple(s.disease for s in scoring.rank(kb, ["high fever", "headache"])[:5])
            for _ in range(10)
        }
        assert len(runs) == 1

    def test_candidates_restrict_the_pool(self, kb):
        scores = scoring.rank(
            kb, ["high fever"], candidates=["malaria", "dengue"],
            include_other=False,
        )
        assert {s.disease for s in scores} == {"malaria", "dengue"}

    def test_the_escape_hatch_joins_every_ranking_by_default(self, kb):
        scores = scoring.rank(kb, ["high fever"], candidates=["malaria", "dengue"])
        assert scoring.OTHER_DISEASE in {s.disease for s in scores}


class TestDenials:
    def test_denials_change_the_ranking(self, kb):
        """Regression: "no" answers narrowed a list the scorer never consulted.

        Fever + headache + chills + nausea leaves dengue and typhoid tied.
        Ruling out vomiting and fatigue should break that tie.
        """
        confirmed = ["high fever", "headache", "chills", "nausea"]
        before = scoring.rank(kb, confirmed)
        after = scoring.rank(kb, confirmed, denied=["vomiting", "fatigue"])
        assert before[0].disease != after[0].disease
        assert after[0].probability > before[0].probability

    def test_denying_a_hallmark_symptom_lowers_that_disease(self, kb):
        """Ruling out a symptom a disease usually presents with is evidence
        against it, and evidence for whichever rival does without it."""
        confirmed = ["itching", "skin rash"]
        before = {s.disease: s.probability for s in scoring.rank(kb, confirmed)}
        after = {
            s.disease: s.probability
            for s in scoring.rank(kb, confirmed, denied=["nodal skin eruptions"])
        }
        # "nodal skin eruptions" is a fungal infection hallmark, so denying it
        # should push probability mass away from fungal infection.
        assert after["fungal infection"] < before["fungal infection"]
        assert after["chicken pox"] > before["chicken pox"]

    def test_denial_alone_is_usable_evidence(self, kb):
        assert scoring.rank(kb, [], denied=["high fever"]) != []

    def test_a_symptom_cannot_be_both_confirmed_and_denied(self, kb):
        both = scoring.rank(kb, ["high fever"], denied=["high fever"])
        confirmed_only = scoring.rank(kb, ["high fever"])
        assert [s.disease for s in both] == [s.disease for s in confirmed_only]


class TestLongSymptomLists:
    def test_evidence_beats_brevity(self, kb):
        """The old ratio score punished diseases for having long symptom lists.

        Matching many of a long-listed disease's symptoms is stronger evidence
        than matching a couple of a short-listed one, and should rank higher.
        """
        long_disease = max(kb.disease_symptoms, key=lambda d: len(kb.disease_symptoms[d]))
        many = sorted(kb.disease_symptoms[long_disease])[:8]
        scores = scoring.rank(kb, many)
        assert scores[0].disease == long_disease


class TestGuards:
    def test_serious_conditions_need_corroboration(self, kb):
        scores = scoring.rank(kb, ["vomiting"])
        guarded = scoring.apply_guards(scores, ["vomiting"])
        names = {s.disease for s in guarded}
        assert not names & set(scoring.GUARDED_DISEASES)

    def test_guards_allow_well_supported_serious_conditions(self, kb):
        symptoms = sorted(kb.disease_symptoms["heart attack"])
        scores = scoring.apply_guards(scoring.rank(kb, symptoms), symptoms)
        assert "heart attack" in {s.disease for s in scores}


class TestBands:
    def test_band_thresholds(self, kb):
        scores = scoring.rank(kb, ["itching", "skin rash", "nodal skin eruptions"])
        assert scores[0].band == scoring.BAND_LIKELY

    def test_thin_evidence_is_capped_below_likely(self, kb):
        scores = scoring.rank(kb, ["itching", "skin rash", "nodal skin eruptions"])
        assert scoring.resolve_band(scores[0], evidence_count=1) == scoring.BAND_POSSIBLE
        assert scoring.resolve_band(scores[0], evidence_count=3) == scoring.BAND_LIKELY

    def test_every_band_has_a_label(self):
        for band in (scoring.BAND_LIKELY, scoring.BAND_POSSIBLE, scoring.BAND_UNCLEAR):
            assert scoring.band_label(band)


class TestNextQuestion:
    def test_picks_an_unasked_symptom(self, kb):
        scores = scoring.rank(kb, ["high fever"])
        chosen = scoring.next_question_symptom(kb, scores, asked=["high fever"])
        assert chosen in kb.vocabulary
        assert chosen != "high fever"

    def test_never_repeats_an_asked_symptom(self, kb):
        scores = scoring.rank(kb, ["high fever"])
        asked = ["high fever"]
        for _ in range(5):
            chosen = scoring.next_question_symptom(kb, scores, asked)
            if chosen is None:
                break
            assert chosen not in asked
            asked.append(chosen)

    def test_is_deterministic(self, kb):
        scores = scoring.rank(kb, ["high fever", "headache"])
        picks = {
            scoring.next_question_symptom(kb, scores, ["high fever", "headache"])
            for _ in range(10)
        }
        assert len(picks) == 1

    def test_returns_none_when_nothing_is_left(self, kb):
        scores = scoring.rank(kb, ["high fever"])
        assert scoring.next_question_symptom(kb, scores, asked=kb.vocabulary) is None

    def test_returns_none_without_candidates(self, kb):
        assert scoring.next_question_symptom(kb, [], asked=[]) is None
