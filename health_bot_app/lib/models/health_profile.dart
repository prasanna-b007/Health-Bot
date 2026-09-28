import 'dart:convert';

/// Biological sex, as the risk engine understands it.
///
/// Kept deliberately small and optional. It exists because it changes triage
/// advice for some presentations, not to categorise the user, and
/// [unspecified] is a first-class answer rather than a missing one.
enum ProfileSex {
  unspecified('Prefer not to say'),
  female('Female'),
  male('Male'),
  other('Other');

  const ProfileSex(this.label);
  final String label;

  static ProfileSex fromName(String? name) => ProfileSex.values.firstWhere(
    (s) => s.name == name,
    orElse: () => ProfileSex.unspecified,
  );
}

/// What the app remembers about the person using it.
///
/// This exists to stop the app asking the same four questions every time
/// someone feels unwell. Everything on it is optional: a profile with nothing
/// filled in is valid, and the app must work exactly as before when it is
/// empty.
///
/// It is stored on the device only, and most of it never leaves: name, sex,
/// [allergies] and [medications] are for the user and for the report they
/// share with a clinician.
///
/// Two fields do travel, with an assessment and only with an assessment:
/// [age], which prefills the form the user still confirms by hand, and
/// [conditions], which the risk engine uses — asthma alongside a confirmed
/// respiratory symptom escalates the risk band. Anything sent has to earn it
/// by changing the result; see `backend/actions/comorbidity.py`.
class HealthProfile {
  const HealthProfile({
    this.name,
    this.age,
    this.sex = ProfileSex.unspecified,
    this.conditions = const [],
    this.allergies = const [],
    this.medications = const [],
    this.smokingHistory,
    this.alcoholHistory,
    this.drugHistory,
  });

  /// First name, used for the greeting. Null means greet without a name.
  final String? name;

  final int? age;
  final ProfileSex sex;

  /// Ongoing conditions (asthma, diabetes, …).
  final List<String> conditions;

  /// Known allergies, including drug allergies.
  final List<String> allergies;

  /// Current medications.
  final List<String> medications;

  /// Lifestyle details (smoking).
  final String? smokingHistory;

  /// Lifestyle details (alcohol).
  final String? alcoholHistory;

  /// Lifestyle details (drugs).
  final String? drugHistory;

  static const HealthProfile empty = HealthProfile();

  bool get hasName => (name ?? '').trim().isNotEmpty;

  /// True once the profile carries anything worth prefilling from.
  bool get isConfigured =>
      hasName ||
      age != null ||
      sex != ProfileSex.unspecified ||
      conditions.isNotEmpty ||
      allergies.isNotEmpty ||
      medications.isNotEmpty ||
      (smokingHistory ?? '').trim().isNotEmpty ||
      (alcoholHistory ?? '').trim().isNotEmpty ||
      (drugHistory ?? '').trim().isNotEmpty;

  /// Everything a clinician would want repeated back, as flat lines. Used by
  /// the shareable report so the context travels with the assessment.
  List<String> get contextLines => [
    if (conditions.isNotEmpty) 'Conditions: ${conditions.join(', ')}',
    if (allergies.isNotEmpty) 'Allergies: ${allergies.join(', ')}',
    if (medications.isNotEmpty) 'Medications: ${medications.join(', ')}',
    if ((smokingHistory ?? '').trim().isNotEmpty) 'Smoking: $smokingHistory',
    if ((alcoholHistory ?? '').trim().isNotEmpty) 'Alcohol: $alcoholHistory',
    if ((drugHistory ?? '').trim().isNotEmpty) 'Drugs: $drugHistory',
  ];

  /// How many of the six fields are filled — drives the profile completeness
  /// meter, which is the only nudge the app makes toward filling it in.
  int get filledCount => [
    hasName,
    age != null,
    sex != ProfileSex.unspecified,
    conditions.isNotEmpty,
    allergies.isNotEmpty,
    medications.isNotEmpty,
    (smokingHistory ?? '').trim().isNotEmpty,
    (alcoholHistory ?? '').trim().isNotEmpty,
    (drugHistory ?? '').trim().isNotEmpty,
  ].where((f) => f).length;

  static const int fieldCount = 9;

  HealthProfile copyWith({
    String? name,
    bool clearName = false,
    int? age,
    bool clearAge = false,
    ProfileSex? sex,
    List<String>? conditions,
    List<String>? allergies,
    List<String>? medications,
    String? smokingHistory,
    bool clearSmokingHistory = false,
    String? alcoholHistory,
    bool clearAlcoholHistory = false,
    String? drugHistory,
    bool clearDrugHistory = false,
  }) {
    return HealthProfile(
      name: clearName ? null : (name ?? this.name),
      age: clearAge ? null : (age ?? this.age),
      sex: sex ?? this.sex,
      conditions: conditions ?? this.conditions,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      smokingHistory: clearSmokingHistory ? null : (smokingHistory ?? this.smokingHistory),
      alcoholHistory: clearAlcoholHistory ? null : (alcoholHistory ?? this.alcoholHistory),
      drugHistory: clearDrugHistory ? null : (drugHistory ?? this.drugHistory),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'sex': sex.name,
    'conditions': conditions,
    'allergies': allergies,
    'medications': medications,
    'smokingHistory': smokingHistory,
    'alcoholHistory': alcoholHistory,
    'drugHistory': drugHistory,
  };

  static HealthProfile fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? raw) => raw is List
        ? raw.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
        : const [];

    final rawAge = json['age'];
    return HealthProfile(
      name: (json['name'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['name'] as String).trim(),
      age: rawAge is int ? rawAge : int.tryParse('${rawAge ?? ''}'),
      sex: ProfileSex.fromName(json['sex'] as String?),
      conditions: strings(json['conditions']),
      allergies: strings(json['allergies']),
      medications: strings(json['medications']),
      smokingHistory: (json['smokingHistory'] as String?)?.trim().isEmpty ?? true ? null : (json['smokingHistory'] as String).trim(),
      alcoholHistory: (json['alcoholHistory'] as String?)?.trim().isEmpty ?? true ? null : (json['alcoholHistory'] as String).trim(),
      drugHistory: (json['drugHistory'] as String?)?.trim().isEmpty ?? true ? null : (json['drugHistory'] as String).trim(),
    );
  }

  String encode() => jsonEncode(toJson());

  /// Decodes stored JSON, falling back to [empty] rather than throwing.
  ///
  /// A profile that fails to parse — a partial write, a format change between
  /// app versions — must never be able to stop someone reaching triage, so a
  /// bad record is treated as no record.
  static HealthProfile decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return empty;
      return fromJson(decoded);
    } on FormatException {
      return empty;
    }
  }
}
