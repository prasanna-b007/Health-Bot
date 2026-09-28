import 'package:flutter/foundation.dart';

import '../models/assessment_data.dart';
import 'rasa_service.dart';

/// High-level API service that wraps [RasaService] and translates raw Rasa
/// responses into typed Flutter models consumed by the UI.
///
/// One instance is one conversation: the sender ID it holds is what keeps Rasa
/// slots continuous across screens, so pass the same instance down rather than
/// constructing a new one per screen.
class ApiService {
  ApiService({RasaService? rasa}) : _rasa = rasa ?? RasaService();

  final RasaService _rasa;

  String get sessionId => _rasa.senderId;

  /// Reset Rasa session (new sender ID = clean conversation context).
  void resetSession() => _rasa.resetSession();

  void dispose() => _rasa.dispose();

  // -----------------------------------------------------------------------
  // Send initial symptoms with assessment metadata
  // -----------------------------------------------------------------------

  /// Sends the symptom text together with assessment metadata (age, duration,
  /// severity) so the backend auto-populates those slots and skips asking.
  ///
  /// [conditions] are the ongoing conditions from the user's stored profile.
  /// They are sent because the risk engine uses them: asthma alongside a
  /// confirmed respiratory symptom escalates the band, which changes the
  /// advice the user is given. Passing them is the caller's decision, not this
  /// class's — nothing here reaches into the profile store on its own.
  ///
  /// Allergies and medications are deliberately *not* sent. The engine has no
  /// rule that consumes them, and uploading medical data that changes nothing
  /// would be collection for its own sake.
  Future<TriageResponse> sendSymptoms(
    AssessmentData data, {
    List<String> conditions = const [],
  }) async {
    return _send(
      data.symptoms,
      metadata: {
        'age': data.age,
        'duration': data.durationDays,
        'severity': data.severity,
        if (conditions.isNotEmpty) 'conditions': conditions,
      },
    );
  }

  /// Sends "yes", "no", or "I'm not sure" to continue the triage conversation.
  Future<TriageResponse> answerQuestion(AnswerType answer) {
    return _send(switch (answer) {
      AnswerType.yes => 'yes',
      AnswerType.no => 'no',
      AnswerType.unsure => "I'm not sure",
    });
  }

  /// Sends a free-text reply (used for numeric intake answers).
  Future<TriageResponse> sendText(String text) => _send(text);

  Future<TriageResponse> _send(
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final responses = await _rasa.sendMessage(message, metadata: metadata);
      return _parseTriageResponse(responses);
    } on RasaException catch (e) {
      // Distinguish the failure modes. Previously every exception — including
      // a parsing bug in this file — was reported as "could not connect",
      // which sent users to check their network for an app-side defect.
      debugPrint('$e (cause: ${e.cause})');
      return TriageResponse(
        isEmergency: false,
        errorMessage: switch (e.kind) {
          RasaErrorKind.network =>
            'Could not reach the health server. Please check your connection and try again.',
          RasaErrorKind.server =>
            'The health server is having trouble right now. Please try again shortly.',
          RasaErrorKind.parse =>
            'The health server sent something we could not read. Please try again.',
          RasaErrorKind.unauthorized =>
            'This app is not authorised to reach the health server. Please update the app.',
        },
      );
    }
  }

  // -----------------------------------------------------------------------
  // Response parser
  // -----------------------------------------------------------------------

  @visibleForTesting
  TriageResponse parseForTest(List<RasaResponse> responses) =>
      _parseTriageResponse(responses);

  TriageResponse _parseTriageResponse(List<RasaResponse> responses) {
    if (responses.isEmpty) {
      return TriageResponse(
        isEmergency: false,
        errorMessage: 'No response from server.',
      );
    }

    // Scan ALL responses — a result or emergency can arrive alongside plain
    // text messages such as "Was this helpful?".
    for (final r in responses) {
      if (r.isEmergency) {
        final crisis = r.isCrisis;
        return TriageResponse(
          isEmergency: true,
          isCrisis: crisis,
          // A crisis disclosure is never echoed back to the user. The backend
          // already withholds the matched phrase; this makes sure the app
          // cannot substitute the raw message text for it either.
          emergencyReason: crisis
              ? null
              : (r.custom?['reason'] as String?) ??
                    r.text ??
                    'Emergency symptoms detected.',
        );
      }
      if (r.isResult) {
        return TriageResponse(isEmergency: false, result: _parseResult(r));
      }
    }

    for (final r in responses) {
      if (r.isQuestion) {
        return TriageResponse(
          isEmergency: false,
          nextQuestion: _parseQuestion(r),
        );
      }
    }

    // Not understood: surface the backend's own wording.
    return TriageResponse(
      isEmergency: false,
      errorMessage:
          responses.last.text ??
          'Could not understand symptoms. Please try again.',
    );
  }

  AssessmentResult _parseResult(RasaResponse r) {
    final custom = r.custom ?? const <String, dynamic>{};

    final altRaw = custom['alternatives'] as List<dynamic>? ?? const [];
    final alternativesRaw = altRaw
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final alternateNames = alternativesRaw
        .map((a) => '${a['name']} (${a['confidence']}%)')
        .toList();

    final adviceRaw = custom['advice'] as List<dynamic>? ?? const [];
    final adviceText = adviceRaw.map((a) => '• $a').join('\n');

    final band = ConfidenceBand.fromString(
      custom['confidence_band'] as String?,
    );

    return AssessmentResult(
      conditionName:
          (custom['top_condition'] as String?) ??
          (custom['condition'] as String?) ??
          '',
      matchPercentage: (custom['confidence'] as num?)?.toDouble() ?? 0.0,
      confidenceBand: band,
      confidenceLabel: (custom['confidence_label'] as String?) ?? band.label,
      alternateMatches: alternateNames,
      riskLevel: (custom['risk'] as String?) ?? 'medium',
      riskScore: (custom['risk_score'] as num?)?.toInt() ?? 0,
      riskFactors: _stringList(custom['risk_factors']),
      advice: adviceText.isNotEmpty ? adviceText : (r.text ?? ''),
      recommendedAction: (custom['recommended_action'] as String?) ?? '',
      matchedSymptoms: _stringList(custom['matched_symptoms']),
      ruledOutSymptoms: _stringList(custom['ruled_out_symptoms']),
      alternativesRaw: alternativesRaw,
      specialist: custom['specialist'] is Map
          ? SpecialistInfo.fromJson(
              Map<String, dynamic>.from(custom['specialist'] as Map),
            )
          : null,
      disposition: Disposition.fromString(custom['disposition'] as String?),
      dispositionLabel: custom['disposition_label'] as String?,
      dispositionTimeframe: custom['disposition_timeframe'] as String?,
      dispositionDetail: (custom['disposition_detail'] as String?) ?? '',
      isUnspecified: custom['is_unspecified'] == true,
      changesAnswer: ChangesAnswer.fromJson(custom['changes_answer']),
      carePlan: custom['care_plan'] is Map
          ? CarePlan.fromJson(
              Map<String, dynamic>.from(custom['care_plan'] as Map),
            )
          : const CarePlan(),
    );
  }

  TriageQuestion _parseQuestion(RasaResponse r) {
    final custom = r.custom ?? const <String, dynamic>{};
    final number = (custom['question_number'] as num?)?.toInt() ?? 1;
    return TriageQuestion(
      text:
          (custom['question'] as String?) ??
          (custom['question_text'] as String?) ??
          r.text ??
          'Please answer:',
      id: 'q$number',
      inputType: (custom['input_type'] as String?) ?? 'yes_no',
      questionNumber: number,
      reason: (custom['reason'] as String?) ?? '',
      estimatedTotal: (custom['estimated_total'] as num?)?.toInt() ?? 5,
    );
  }

  static List<String> _stringList(Object? raw) =>
      (raw as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}

// ---------------------------------------------------------------------------
// Response wrapper
// ---------------------------------------------------------------------------

class TriageResponse {
  TriageResponse({
    required this.isEmergency,
    this.isCrisis = false,
    this.emergencyReason,
    this.nextQuestion,
    this.result,
    this.errorMessage,
  });

  final bool isEmergency;

  /// True when the user disclosed suicidal thoughts or self-harm.
  ///
  /// Still an emergency — [isEmergency] is also true, so any caller that only
  /// knows about emergencies still escalates rather than silently carrying on
  /// with triage. Callers that know about crises route to [CrisisScreen]
  /// instead of the hospital finder, which is the whole point of the flag.
  final bool isCrisis;
  final String? emergencyReason;
  final TriageQuestion? nextQuestion;
  final AssessmentResult? result;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}
