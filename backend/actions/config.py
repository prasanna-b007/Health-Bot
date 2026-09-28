"""Tunable thresholds for the triage engine.

Every magic number the engine branches on lives here so it can be reviewed in
one place. Several of these previously existed in config but were ignored by
the code, which branched on its own hardcoded copies -- AGE_RISK said 65 while
the risk function tested 60, and DURATION_RISK_DAYS/SEVERITY_HIGH were never
read at all.
"""

THRESHOLDS = {
    # Posterior probability (0-1) at which we stop asking questions and commit.
    "CONFIDENCE_DECISIVE": 0.60,
    # Below this posterior we decline to name a condition at all.
    "CONFIDENCE_MINIMUM": 0.15,

    # Self-reported severity (1-10) bands used in risk scoring.
    "SEVERITY_HIGH": 7,
    "SEVERITY_MODERATE": 4,

    # Age at which we add an age-related vulnerability factor. Set to 60 to
    # preserve the behaviour the risk function actually had.
    "AGE_RISK": 60,
    "AGE_CHILD": 12,
    "AGE_INFANT": 2,

    # Plausibility bounds for user-supplied intake values. Age, duration and
    # severity all feed risk scoring directly, so an out-of-range value is
    # rejected rather than trusted -- the client validates too, but the client
    # is not the only thing that can talk to this server.
    "AGE_MIN": 0,
    "AGE_MAX": 120,
    "DURATION_MIN_DAYS": 0,
    "DURATION_MAX_DAYS": 3650,
    "SEVERITY_MIN": 1,
    "SEVERITY_MAX": 10,

    # Chronic-condition contribution to the risk score (see comorbidity.py).
    # Points are per vulnerability *group*, not per condition, and capped, so a
    # long profile cannot inflate its own risk level by listing more entries.
    "COMORBIDITY_POINTS": 10,
    "COMORBIDITY_MAX": 20,
    # A condition paired with a symptom that condition makes dangerous --
    # asthma with breathlessness. Weighted above the baseline because the
    # combination, not the condition alone, is what escalates care.
    "COMORBIDITY_INTERACTION_POINTS": 15,
    "COMORBIDITY_INTERACTION_MAX": 30,

    # Days a concerning symptom must persist before it adds risk.
    "DURATION_RISK_DAYS": 7,
    # Days within which a severe symptom counts as acute onset.
    "DURATION_ACUTE_DAYS": 2,

    # Two interactions the risk model was missing. Both were found by the
    # evaluation suite, and both were cases of under-triage -- the direction
    # that matters.
    #
    # A severe self-report *alongside* an objectively dangerous symptom is
    # worse than either alone, but the score treated them as independent
    # additions: 8/10 severity with a high-weight symptom reached 55, six
    # points below the High threshold, so a textbook dengue presentation was
    # told to see someone within 72 hours.
    "SEVERITY_DANGER_POINTS": 10,
    # Weeks of illness in an infant or an older adult carried no weight unless
    # one symptom was individually dangerous, so three weeks of productive
    # cough at 74 scored the same as three weeks of it at 30. Persistence is
    # the signal in exactly the groups least able to absorb being wrong.
    "PROLONGED_VULNERABLE_POINTS": 15,
}
