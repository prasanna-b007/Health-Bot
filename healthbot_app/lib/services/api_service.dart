import '../models/assessment_data.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5005'; // Configure as needed (e.g. 10.0.2.2 for emulator)
  static String sessionId = 'test-session';

  // In a real app, this would hit the Rasa REST endpoint.
  // For the UI spec, we mock the responses to demonstrate the flow.

  Future<TriageResponse> sendAssessmentStart(AssessmentData data) async {
    // Mocking the request
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if symptoms contain emergency keywords
    if (data.symptoms.toLowerCase().contains('chest pain') || data.symptoms.toLowerCase().contains('breathing')) {
      return TriageResponse(isEmergency: true, emergencyReason: 'Chest pain or breathing difficulty detected.');
    }

    return TriageResponse(
      isEmergency: false,
      nextQuestion: TriageQuestion(id: 'q1', text: 'Do you have a fever over 101°F?'),
    );
  }

  Future<TriageResponse> answerQuestion(String questionId, bool answer) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (questionId == 'q1') {
      return TriageResponse(
        isEmergency: false,
        nextQuestion: TriageQuestion(id: 'q2', text: 'Have you experienced nausea or vomiting?'),
      );
    } else {
      // Return final result after 2 questions
      return TriageResponse(
        isEmergency: false,
        result: AssessmentResult(
          conditionName: 'Viral Infection',
          matchPercentage: 82.5,
          alternateMatches: ['Common Cold', 'Seasonal Flu'],
          riskLevel: 'medium',
          advice: 'Rest and stay hydrated. Monitor your symptoms and contact a doctor if they worsen after 48 hours.',
        ),
      );
    }
  }

  Future<List<HospitalData>> getNearbyHospitals() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      HospitalData(name: 'City General Hospital', distance: '1.2 mi', phone: '555-0199'),
      HospitalData(name: 'Mercy Medical Center', distance: '3.4 mi', phone: '555-0188'),
      HospitalData(name: 'Westside Urgent Care', distance: '4.1 mi', phone: '555-0177'),
    ];
  }
}

class TriageResponse {
  final bool isEmergency;
  final String? emergencyReason;
  final TriageQuestion? nextQuestion;
  final AssessmentResult? result;

  TriageResponse({
    required this.isEmergency,
    this.emergencyReason,
    this.nextQuestion,
    this.result,
  });
}

class HospitalData {
  final String name;
  final String distance;
  final String phone;

  HospitalData({
    required this.name,
    required this.distance,
    required this.phone,
  });
}
