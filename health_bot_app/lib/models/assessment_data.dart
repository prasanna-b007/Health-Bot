/// How long the user has had their symptoms.
///
/// A real type rather than a display string. The two were previously matched
/// by hand and had drifted apart: the form offered "> 1 week" while the
/// converter tested for ">1 week", so anyone reporting symptoms for over a
/// week had it sent to the backend as **one day** — losing the prolonged-symptom
/// risk factor entirely for exactly the people who most needed it.
enum SymptomDuration {
  oneDay('1 day', 1),
  twoToThreeDays('2-3 days', 3),
  fourToSevenDays('4-7 days', 5),
  overAWeek('> 1 week', 10);

  const SymptomDuration(this.label, this.days);

  /// Text shown to the user.
  final String label;

  /// Representative day count sent to the backend's `duration_days` slot.
  final int days;

  static SymptomDuration fromLabel(String label) {
    final needle = label.replaceAll(' ', '').toLowerCase();
    return SymptomDuration.values.firstWhere(
      (d) => d.label.replaceAll(' ', '').toLowerCase() == needle,
      orElse: () => SymptomDuration.oneDay,
    );
  }
}

class AssessmentData {
  AssessmentData({
    required this.age,
    this.duration = SymptomDuration.oneDay,
    this.severity = 5,
    this.symptoms = '',
  });

  /// The user's age in years. Required — there is no sensible default, and
  /// supplying one invited the previous form to submit a prefilled 22 on
  /// behalf of a user who never typed anything.
  int age;

  SymptomDuration duration;
  int severity;
  String symptoms;

  /// Youngest and oldest ages the assessment accepts.
  ///
  /// The lower bound is 0 because infants are explicitly modelled by the risk
  /// engine; the upper bound is a plausibility ceiling, not a medical one.
  static const int minAge = 0;
  static const int maxAge = 120;

  /// Validation message for an age entry, or null when it is acceptable.
  ///
  /// Age feeds risk scoring directly — an infant and a 70-year-old get
  /// different escalation — so a typo here changes the advice the user gets.
  static String? validateAge(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Please enter your age.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Age must be a number.';
    if (parsed < minAge) return 'Age cannot be negative.';
    if (parsed > maxAge) return 'Please enter an age of $maxAge or less.';
    return null;
  }

  static bool isValidAge(String? raw) => validateAge(raw) == null;

  /// Day count for the backend's `duration_days` slot.
  int get durationDays => duration.days;

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'duration': duration.label,
      'severity': severity,
      'symptoms': symptoms,
    };
  }
}

class TriageQuestion {
  final String text;
  final String id;
  final String inputType; // 'yes_no', 'number', 'text'
  final int questionNumber;
  final String reason;
  final int estimatedTotal;

  TriageQuestion({
    required this.text,
    required this.id,
    this.inputType = 'yes_no',
    this.questionNumber = 1,
    this.reason = '',
    this.estimatedTotal = 5,
  });
}

/// Represents a question + answer pair for the wizard history stack.
class QuestionAnswer {
  final TriageQuestion question;
  final AnswerType answer;

  QuestionAnswer({required this.question, required this.answer});
}

enum AnswerType { yes, no, unsure }

class SpecialistInfo {
  final String name;
  final String description;
  final String department;
  final String priority; // 'Immediate', 'Soon', 'Routine'

  SpecialistInfo({
    required this.name,
    required this.description,
    this.department = '',
    this.priority = 'Routine',
  });

  factory SpecialistInfo.fromJson(Map<String, dynamic> json) {
    return SpecialistInfo(
      name: json['name'] as String? ?? 'General Physician',
      description: json['description'] as String? ?? '',
      department: json['department'] as String? ?? '',
      priority: json['priority'] as String? ?? 'Routine',
    );
  }
}

/// Non-medication next steps for the identified condition.
///
/// Three groups, because "what do I do now" splits cleanly into actions to
/// take, things that make it worse, and the point at which self-care stops
/// being the right answer. The backend authors these per condition; nothing
/// here names a drug or a dose.
class CarePlan {
  final String goal;
  final List<String> doThis;
  final List<String> avoid;
  final List<String> redFlags;

  const CarePlan({
    this.goal = '',
    this.doThis = const [],
    this.avoid = const [],
    this.redFlags = const [],
  });

  factory CarePlan.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) => (json[key] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return CarePlan(
      goal: json['goal'] as String? ?? '',
      doThis: list('do'),
      avoid: list('avoid'),
      redFlags: list('red_flags'),
    );
  }

  /// Nothing worth drawing a card for.
  bool get isEmpty => doThis.isEmpty && avoid.isEmpty && redFlags.isEmpty;
}

/// What the user should actually do, and how soon.
///
/// This is the headline of a result, and the condition name is the supporting
/// detail — the reverse of how the app used to present an assessment.
///
/// The reason is not cosmetic. Naming one condition out of 41 from a teaching
/// dataset is the least reliable thing this app does; working out whether
/// someone needs to be seen now, today, this week, or not at all rests on
/// severity, age, duration and existing conditions, and is the part the
/// engine has the best claim to be right about. Leading with the disposition
/// puts the trustworthy half of the answer first, and it is the half a
/// worried person can act on.
enum Disposition {
  emergency('emergency', 'Emergency care now', 'Now'),
  urgentToday('urgent_today', 'Urgent care today', 'Within 24 hours'),
  seeDoctorSoon('see_doctor_soon', 'See a doctor soon', 'Within 72 hours'),
  selfCare('self_care', 'Self-care and monitor', 'Monitor at home');

  const Disposition(this.code, this.defaultLabel, this.defaultTimeframe);

  final String code;
  final String defaultLabel;
  final String defaultTimeframe;

  /// Unknown values fall back to the gentlest reading rather than inventing
  /// urgency the backend did not ask for.
  static Disposition fromString(String? value) {
    for (final d in Disposition.values) {
      if (d.code == value) return d;
    }
    return Disposition.selfCare;
  }

  /// How urgent this is, for comparisons. Higher is sooner.
  int get urgency => switch (this) {
    Disposition.emergency => 3,
    Disposition.urgentToday => 2,
    Disposition.seeDoctorSoon => 1,
    Disposition.selfCare => 0,
  };
}

/// The single symptom that would most change an assessment.
///
/// Shown as "what would change this answer". A result built from five yes/no
/// questions will sometimes be wrong, and the useful response to that is not a
/// longer disclaimer but telling people exactly where the answer is
/// load-bearing — so someone who does have the symptom knows to go back.
class ChangesAnswer {
  const ChangesAnswer({required this.symptom, required this.condition});

  final String symptom;
  final String condition;

  static ChangesAnswer? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final symptom = raw['symptom']?.toString() ?? '';
    final condition = raw['condition']?.toString() ?? '';
    if (symptom.isEmpty || condition.isEmpty) return null;
    return ChangesAnswer(symptom: symptom, condition: condition);
  }
}

/// How strongly the symptoms point at one condition.
///
/// The backend sends a band alongside the raw percentage. The band is what the
/// UI leads with: the number comes from a 41-condition teaching dataset, and
/// showing "87%" implies a precision the model does not have.
enum ConfidenceBand {
  likely,
  possible,
  unclear;

  static ConfidenceBand fromString(String? value) {
    switch (value) {
      case 'likely':
        return ConfidenceBand.likely;
      case 'possible':
        return ConfidenceBand.possible;
      default:
        return ConfidenceBand.unclear;
    }
  }

  String get label => switch (this) {
    ConfidenceBand.likely => 'Likely match',
    ConfidenceBand.possible => 'Possible match',
    ConfidenceBand.unclear => 'Unclear match',
  };
}

class AssessmentResult {
  final String conditionName;
  final double matchPercentage;
  final ConfidenceBand confidenceBand;
  final String confidenceLabel;
  final List<String> alternateMatches;
  final String riskLevel; // 'low', 'medium', 'high', 'emergency'
  final int riskScore;
  final List<String> riskFactors;
  final String advice;
  final String recommendedAction;
  final List<String> matchedSymptoms;

  /// Symptoms the user explicitly ruled out. These now shape the result, so
  /// showing them explains why one condition was preferred over another.
  final List<String> ruledOutSymptoms;

  final List<Map<String, dynamic>> alternativesRaw;
  final SpecialistInfo specialist;
  final CarePlan carePlan;

  /// What to do and how soon. The headline of the result screen.
  final Disposition disposition;
  final String dispositionLabel;
  final String dispositionTimeframe;
  final String dispositionDetail;

  /// True when the engine declined to name a condition because the symptoms
  /// did not point clearly at one. Distinct from an error: it is a real and
  /// common answer, and the disposition still applies.
  final bool isUnspecified;

  /// The one symptom that would most change this conclusion, if any.
  final ChangesAnswer? changesAnswer;

  AssessmentResult({
    required this.conditionName,
    required this.matchPercentage,
    required this.alternateMatches,
    required this.riskLevel,
    this.confidenceBand = ConfidenceBand.unclear,
    String? confidenceLabel,
    this.riskScore = 0,
    this.riskFactors = const [],
    required this.advice,
    this.recommendedAction = '',
    this.matchedSymptoms = const [],
    this.ruledOutSymptoms = const [],
    this.alternativesRaw = const [],
    SpecialistInfo? specialist,
    this.carePlan = const CarePlan(),
    this.disposition = Disposition.selfCare,
    String? dispositionLabel,
    String? dispositionTimeframe,
    this.dispositionDetail = '',
    this.isUnspecified = false,
    this.changesAnswer,
  }) : confidenceLabel = confidenceLabel ?? confidenceBand.label,
       dispositionLabel = dispositionLabel ?? disposition.defaultLabel,
       dispositionTimeframe =
           dispositionTimeframe ?? disposition.defaultTimeframe,
       specialist =
           specialist ??
           SpecialistInfo(
             name: 'General Physician',
             description: 'A general physician can assess your condition.',
           );

  /// True when the backend declined to name a condition.
  bool get isInconclusive =>
      isUnspecified ||
      conditionName.isEmpty ||
      conditionName.toLowerCase() == 'unknown';
}
