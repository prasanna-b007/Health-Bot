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

  /// Convert the human-readable duration string to an integer
  /// for the Rasa backend (duration_days slot).
  int get durationDays {
    switch (duration) {
      case '1 day':
        return 1;
      case '2-3 days':
        return 3;
      case '4-7 days':
        return 5;
      case '>1 week':
        return 10;
      default:
        return 1;
    }
  }

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

class AssessmentResult {
  final String conditionName;
  final double matchPercentage;
  final List<String> alternateMatches;
  final String riskLevel; // 'low', 'medium', 'high', 'emergency'
  final int riskScore;
  final List<String> riskFactors;
  final String advice;
  final String recommendedAction;
  final List<String> matchedSymptoms;
  final List<Map<String, dynamic>> alternativesRaw;

  AssessmentResult({
    required this.conditionName,
    required this.matchPercentage,
    required this.alternateMatches,
    required this.riskLevel,
    this.riskScore = 0,
    this.riskFactors = const [],
    required this.advice,
    this.recommendedAction = '',
    this.matchedSymptoms = const [],
    this.alternativesRaw = const [],
  });
}
