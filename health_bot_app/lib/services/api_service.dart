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
  // Answer a follow-up question (yes / no / unsure)
  // -----------------------------------------------------------------------

  /// Sends "yes", "no", or "I'm not sure" to continue the Rasa triage conversation.
  Future<TriageResponse> answerQuestion(AnswerType answer) async {
    try {
      String message;
      switch (answer) {
        case AnswerType.yes:
          message = 'yes';
          break;
        case AnswerType.no:
          message = 'no';
          break;
        case AnswerType.unsure:
          message = "I'm not sure";
          break;
      }
      final responses = await _rasa.sendMessage(message);
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
      HospitalData(name: 'City General Hospital', distance: '1.2 km away', rawDistance: 1200, phone: '555-0199', hasEmergency: true, website: '', latitude: 0, longitude: 0, type: 'General Hospital', estimatedTimeMins: 3, address: '123 Main St'),
      HospitalData(name: 'Mercy Medical Center', distance: '3.4 km away', rawDistance: 3400, phone: '555-0188', hasEmergency: false, website: '', latitude: 0, longitude: 0, type: 'Private Hospital', estimatedTimeMins: 7, address: '456 Oak Ave'),
      HospitalData(name: 'Westside Urgent Care', distance: '4.1 km away', rawDistance: 4100, phone: '555-0177', hasEmergency: true, website: '', latitude: 0, longitude: 0, type: 'Medical Facility', estimatedTimeMins: 9, address: '789 Pine Rd'),
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
        
        // Parse matched symptoms
        final matchedRaw = custom['matched_symptoms'] as List<dynamic>? ?? [];
        final matchedSymptoms = matchedRaw.map((s) => s.toString()).toList();
        
        // Parse recommended action
        final recommendedAction = (custom['recommended_action'] as String?) ?? '';
        
        // Parse alternatives as raw maps for the results screen
        final alternativesRaw = altRaw
            .map((a) => a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{})
            .toList();

        // Parse specialist info
        final specialistRaw = custom['specialist'] as Map<String, dynamic>?;
        final specialist = specialistRaw != null
            ? SpecialistInfo.fromJson(specialistRaw)
            : null;

        return TriageResponse(
          isEmergency: false,
          result: AssessmentResult(
            conditionName: (custom['top_condition'] as String?) ?? 
                           (custom['condition'] as String?) ?? 'Unknown',
            matchPercentage:
                (custom['confidence'] as num?)?.toDouble() ?? 0.0,
            alternateMatches: alternateNames.cast<String>(),
            riskLevel: (custom['risk'] as String?) ?? 'medium',
            riskScore: (custom['risk_score'] as int?) ?? 0,
            riskFactors: (custom['risk_factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            advice: adviceText.isNotEmpty ? adviceText : (r.text ?? ''),
            recommendedAction: recommendedAction,
            matchedSymptoms: matchedSymptoms,
            alternativesRaw: alternativesRaw,
            specialist: specialist,
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

    final qCustom = questionResponse.custom ?? {};
    final qText = qCustom['question'] as String? ??
                   qCustom['question_text'] as String? ?? 
                   questionResponse.text ?? 'Please answer:';
    final qNum = qCustom['question_number'] as int? ?? 1;
    final qInput = qCustom['input_type'] as String? ?? 'yes_no';
    final qReason = qCustom['reason'] as String? ?? '';
    final qEstTotal = qCustom['estimated_total'] as int? ?? 5;

    return TriageResponse(
      isEmergency: false,
      nextQuestion: TriageQuestion(
        text: qText,
        id: 'q$qNum',
        inputType: qInput,
        questionNumber: qNum,
        reason: qReason,
        estimatedTotal: qEstTotal,
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
  final double rawDistance;
  final String phone;
  final bool hasEmergency;
  final String website;
  final double latitude;
  final double longitude;
  final String type;
  final int estimatedTimeMins;
  final String address;

  HospitalData({
    required this.name,
    required this.distance,
    required this.rawDistance,
    required this.phone,
    required this.hasEmergency,
    required this.website,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.estimatedTimeMins,
    required this.address,
  });
}
