import 'dart:convert';

import 'assessment_data.dart';

/// A completed assessment, frozen for the history timeline.
///
/// It stores enough to rebuild the full result screen offline — the condition,
/// the risk band, the reasoning, the advice — rather than an id to re-fetch.
/// Triage sessions are stateful on the backend and are not addressable after
/// the fact, so a record that only held a reference would show an empty page
/// the moment the user tapped it.
class AssessmentRecord {
  const AssessmentRecord({
    required this.id,
    required this.takenAt,
    required this.symptoms,
    required this.age,
    required this.durationLabel,
    required this.severity,
    required this.riskLevel,
    required this.conditionName,
    required this.matchPercentage,
    required this.confidenceLabel,
    required this.advice,
    required this.recommendedAction,
    required this.specialistName,
    required this.specialistDescription,
    this.riskScore = 0,
    this.matchedSymptoms = const [],
    this.ruledOutSymptoms = const [],
    this.alternateMatches = const [],
    this.riskFactors = const [],
  });

  final String id;
  final DateTime takenAt;

  final String symptoms;
  final int age;
  final String durationLabel;
  final int severity;

  final String riskLevel;
  final int riskScore;
  final String conditionName;
  final double matchPercentage;
  final String confidenceLabel;
  final String advice;
  final String recommendedAction;
  final String specialistName;
  final String specialistDescription;
  final List<String> matchedSymptoms;
  final List<String> ruledOutSymptoms;
  final List<String> alternateMatches;
  final List<String> riskFactors;

  /// Builds a record from a finished assessment.
  factory AssessmentRecord.from({
    required AssessmentData data,
    required AssessmentResult result,
    DateTime? takenAt,
  }) {
    final when = takenAt ?? DateTime.now();
    return AssessmentRecord(
      // Microsecond timestamps are unique enough for a single-device,
      // append-only list and keep the ids sortable.
      id: when.microsecondsSinceEpoch.toString(),
      takenAt: when,
      symptoms: data.symptoms,
      age: data.age,
      durationLabel: data.duration.label,
      severity: data.severity,
      riskLevel: result.riskLevel,
      riskScore: result.riskScore,
      conditionName: result.conditionName,
      matchPercentage: result.matchPercentage,
      confidenceLabel: result.confidenceLabel,
      advice: result.advice,
      recommendedAction: result.recommendedAction,
      specialistName: result.specialist.name,
      specialistDescription: result.specialist.description,
      matchedSymptoms: result.matchedSymptoms,
      ruledOutSymptoms: result.ruledOutSymptoms,
      alternateMatches: result.alternateMatches,
      riskFactors: result.riskFactors,
    );
  }

  /// Rebuilds the inputs so an archived record can be shown on the same
  /// results screen as a fresh one.
  AssessmentData toData() => AssessmentData(
    age: age,
    duration: SymptomDuration.fromLabel(durationLabel),
    severity: severity,
    symptoms: symptoms,
  );

  AssessmentResult toResult() => AssessmentResult(
    conditionName: conditionName,
    matchPercentage: matchPercentage,
    confidenceLabel: confidenceLabel,
    alternateMatches: alternateMatches,
    riskLevel: riskLevel,
    riskScore: riskScore,
    riskFactors: riskFactors,
    advice: advice,
    recommendedAction: recommendedAction,
    matchedSymptoms: matchedSymptoms,
    ruledOutSymptoms: ruledOutSymptoms,
    specialist: SpecialistInfo(
      name: specialistName,
      description: specialistDescription,
    ),
  );

  /// A short human summary for the timeline row: the condition when the
  /// backend named one, otherwise the symptoms the user described.
  String get headline {
    final named = conditionName.trim();
    if (named.isNotEmpty && named.toLowerCase() != 'unknown') return named;
    final typed = symptoms.trim();
    if (typed.isEmpty) return 'Assessment';
    return typed[0].toUpperCase() + typed.substring(1);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'takenAt': takenAt.toIso8601String(),
    'symptoms': symptoms,
    'age': age,
    'durationLabel': durationLabel,
    'severity': severity,
    'riskLevel': riskLevel,
    'riskScore': riskScore,
    'conditionName': conditionName,
    'matchPercentage': matchPercentage,
    'confidenceLabel': confidenceLabel,
    'advice': advice,
    'recommendedAction': recommendedAction,
    'specialistName': specialistName,
    'specialistDescription': specialistDescription,
    'matchedSymptoms': matchedSymptoms,
    'ruledOutSymptoms': ruledOutSymptoms,
    'alternateMatches': alternateMatches,
    'riskFactors': riskFactors,
  };

  /// Returns null for a record that cannot be read, so one corrupt entry is
  /// skipped instead of taking the whole history down with it.
  static AssessmentRecord? fromJson(Map<String, dynamic> json) {
    final takenAt = DateTime.tryParse('${json['takenAt']}');
    if (takenAt == null) return null;

    List<String> strings(Object? raw) =>
        raw is List ? raw.whereType<String>().toList() : const [];

    return AssessmentRecord(
      id: '${json['id'] ?? takenAt.microsecondsSinceEpoch}',
      takenAt: takenAt,
      symptoms: '${json['symptoms'] ?? ''}',
      age: (json['age'] as num?)?.toInt() ?? 0,
      durationLabel: '${json['durationLabel'] ?? ''}',
      severity: (json['severity'] as num?)?.toInt() ?? 0,
      riskLevel: '${json['riskLevel'] ?? 'medium'}',
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      conditionName: '${json['conditionName'] ?? ''}',
      matchPercentage: (json['matchPercentage'] as num?)?.toDouble() ?? 0,
      confidenceLabel: '${json['confidenceLabel'] ?? ''}',
      advice: '${json['advice'] ?? ''}',
      recommendedAction: '${json['recommendedAction'] ?? ''}',
      specialistName: '${json['specialistName'] ?? 'General Physician'}',
      specialistDescription: '${json['specialistDescription'] ?? ''}',
      matchedSymptoms: strings(json['matchedSymptoms']),
      ruledOutSymptoms: strings(json['ruledOutSymptoms']),
      alternateMatches: strings(json['alternateMatches']),
      riskFactors: strings(json['riskFactors']),
    );
  }

  static String encodeList(List<AssessmentRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());

  static List<AssessmentRecord> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .whereType<AssessmentRecord>()
          .toList();
    } on FormatException {
      return const [];
    }
  }
}
