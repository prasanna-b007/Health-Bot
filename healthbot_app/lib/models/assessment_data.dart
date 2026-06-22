class AssessmentData {
  int age;
  String duration;
  int severity;
  String symptoms;

  AssessmentData({
    this.age = 30,
    this.duration = '1 day',
    this.severity = 5,
    this.symptoms = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'duration': duration,
      'severity': severity,
      'symptoms': symptoms,
    };
  }
}

class TriageQuestion {
  final String text;
  final String id;

  TriageQuestion({required this.text, required this.id});
}

class AssessmentResult {
  final String conditionName;
  final double matchPercentage;
  final List<String> alternateMatches;
  final String riskLevel; // 'low', 'medium', 'high', 'emergency'
  final String advice;

  AssessmentResult({
    required this.conditionName,
    required this.matchPercentage,
    required this.alternateMatches,
    required this.riskLevel,
    required this.advice,
  });
}
