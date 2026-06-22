import '../models/assessment_data.dart';
import 'rasa_service.dart';

/// High-level API service that wraps [RasaService] and translates
/// raw Rasa responses into typed Flutter models consumed by the UI.
class ApiService {
  final RasaService _rasa = RasaService();

  String get sessionId => _rasa.senderId;

  /// Reset Rasa session (new sender ID = clean conversation context).
  void resetSession() => _rasa.resetSession();

  // -----------------------------------------------------------------------
  // Send initial symptoms with assessment metadata
  // -----------------------------------------------------------------------

  /// Called from SymptomInputScreen after the user types their symptoms.
  ///
  /// Sends the symptom text together with assessment metadata (age,
  /// duration, severity) so the Rasa backend auto-populates those slots
  /// and skips asking for them during triage.
  Future<TriageResponse> sendSymptoms(AssessmentData data) async {
    try {
      final responses = await _rasa.sendMessage(
        data.symptoms,
        metadata: {
          'age': data.age,
          'duration': data.durationDays,
          'severity': data.severity,
        },
      );
      return _parseTriageResponse(responses);
    } catch (e) {
      return TriageResponse(
        isEmergency: false,
        errorMessage: 'Could not connect to the health server. Please check your connection and try again.',
      );
    }
  }

  // -----------------------------------------------------------------------
  // Answer a follow-up question
  // -----------------------------------------------------------------------

  /// Sends "yes" or "no" to continue the Rasa triage conversation.
  Future<TriageResponse> answerQuestion(bool answer) async {
    try {
      final responses = await _rasa.sendMessage(answer ? 'yes' : 'no');
      return _parseTriageResponse(responses);
    } catch (e) {
      return TriageResponse(
        isEmergency: false,
        errorMessage: 'Connection error. Please try again.',
      );
    }
  }

  // -----------------------------------------------------------------------
  // Nearby hospitals (static data — no backend required)
  // -----------------------------------------------------------------------

  Future<List<HospitalData>> getNearbyHospitals() async {
    // In a production app this would call a location API.
    // Kept as static data to avoid an external dependency.
    return [
      HospitalData(name: 'City General Hospital', distance: '1.2 mi', phone: '555-0199'),
      HospitalData(name: 'Mercy Medical Center', distance: '3.4 mi', phone: '555-0188'),
      HospitalData(name: 'Westside Urgent Care', distance: '4.1 mi', phone: '555-0177'),
    ];
  }

  // -----------------------------------------------------------------------
  // Response parser
  // -----------------------------------------------------------------------

  TriageResponse _parseTriageResponse(List<RasaResponse> responses) {
    if (responses.isEmpty) {
      return TriageResponse(
        isEmergency: false,
        errorMessage: 'No response from server.',
      );
    }

    // Scan ALL responses for emergency or result (they may arrive
    // alongside plain text messages like "Was this helpful?").
    for (final r in responses) {
      if (r.isEmergency) {
        return TriageResponse(
          isEmergency: true,
          emergencyReason: r.text ?? 'Emergency symptoms detected.',
        );
      }

      if (r.isResult) {
        final custom = r.custom!;
        final altRaw = custom['alternatives'] as List<dynamic>? ?? [];
        final alternateNames = altRaw
            .map((a) {
              if (a is Map) return '${a["name"]} (${a["confidence"]}%)';
              return a.toString();
            })
            .toList();
        final adviceRaw = custom['advice'] as List<dynamic>? ?? [];
        final adviceText = adviceRaw.map((a) => '• $a').join('\n');

        return TriageResponse(
          isEmergency: false,
          result: AssessmentResult(
            conditionName: (custom['condition'] as String?) ?? 'Unknown',
            matchPercentage:
                (custom['confidence'] as num?)?.toDouble() ?? 0.0,
            alternateMatches: alternateNames.cast<String>(),
            riskLevel: (custom['risk'] as String?) ?? 'medium',
            riskScore: (custom['risk_score'] as int?) ?? 0,
            riskFactors: (custom['risk_factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            advice: adviceText.isNotEmpty ? adviceText : (r.text ?? ''),
          ),
        );
      }
    }

    // No emergency or result found → treat as a follow-up question.
    RasaResponse? questionResponse;
    for (final r in responses) {
      if (r.isQuestion) questionResponse = r;
    }
    
    // If no structured question was found, treat it as a fallback/error message
    if (questionResponse == null) {
      return TriageResponse(
        isEmergency: false,
        errorMessage: responses.last.text ?? 'Could not understand symptoms. Please try again.',
      );
    }

    final qText = questionResponse.custom?['question_text'] as String? ?? questionResponse.text ?? 'Please answer:';
    final qNum = questionResponse.custom?['question_number'] as int? ?? 1;
    final qInput = questionResponse.custom?['input_type'] as String? ?? 'yes_no';

    return TriageResponse(
      isEmergency: false,
      nextQuestion: TriageQuestion(
        text: qText,
        id: 'q$qNum',
        inputType: qInput,
        questionNumber: qNum,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Response wrapper
// ---------------------------------------------------------------------------

class TriageResponse {
  final bool isEmergency;
  final String? emergencyReason;
  final TriageQuestion? nextQuestion;
  final AssessmentResult? result;
  final String? errorMessage;

  TriageResponse({
    required this.isEmergency,
    this.emergencyReason,
    this.nextQuestion,
    this.result,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

// ---------------------------------------------------------------------------
// Hospital data (static)
// ---------------------------------------------------------------------------

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
