"""The prior over conditions."""
import pytest

from actions import prevalence, scoring


class TestTiers:
    def test_every_condition_in_the_dataset_has_a_tier(self, kb):
        """An untiered condition silently scores as 'uncommon' forever."""
        assert prevalence.unmapped(kb.disease_symptoms) == []

    def test_tier_weights_are_ordered(self):
        weights = prevalence.TIER_WEIGHTS
        assert (
            weights["very_common"] > weights["common"]
            > weights["uncommon"] > weights["rare"] > 0
        )

    def test_common_conditions_outweigh_rare_ones(self):
        assert prevalence.weight_of("common cold") > prevalence.weight_of("aids")


class TestRegions:
    def test_unknown_region_falls_back_rather_than_failing(self):
        """A mistyped environment variable must not take triage offline."""
        assert prevalence.resolve_region("atlantis") == prevalence.DEFAULT_REGION

    def test_region_overrides_the_baseline(self):
        assert prevalence.tier_of("dengue", "global") == "uncommon"
        assert prevalence.tier_of("dengue", "south_asia") == "common"
        assert prevalence.tier_of("dengue", "europe") == "rare"

    def test_regions_only_change_what_they_list(self):
        for region in prevalence.available_regions():
            assert prevalence.tier_of("migraine", region) == "very_common"

    def test_region_names_are_forgiving(self):
        assert prevalence.resolve_region("South-Asia") == "south_asia"
        assert prevalence.resolve_region("SOUTH ASIA") == "south_asia"


class TestPrior:
    def test_prior_is_a_distribution(self, kb):
        prior = scoring.priors(kb)
        assert pytest.approx(sum(prior.values()), abs=1e-9) == 1.0
        assert all(weight > 0 for weight in prior.values())

    def test_unspecified_illness_holds_its_share(self, kb):
        prior = scoring.priors(kb)
        assert prior[scoring.OTHER_DISEASE] == pytest.approx(
            scoring.OTHER_PRIOR_SHARE
        )

    def test_the_prior_separates_conditions_that_fit_equally_well(self, kb):
        """The point of the whole module.

        "extra marital contacts" is recorded for AIDS and nothing else, so
        likelihood alone cannot be what keeps AIDS off the screen for someone
        reporting a common symptom set -- only the prior can.
        """
        prior = scoring.priors(kb)
        assert prior["common cold"] > prior["aids"] * 10

    def test_region_changes_the_ranking_for_the_same_evidence(self, kb):
        evidence = ["high fever", "chills", "sweating", "vomiting", "headache"]
        confidence = {}
        for region in ("europe", "south_asia"):
            scores = scoring.rank(kb, evidence, region=region)
            confidence[region] = next(
                s.probability for s in scores if s.disease == "malaria"
            )
        assert confidence["south_asia"] > confidence["europe"]
