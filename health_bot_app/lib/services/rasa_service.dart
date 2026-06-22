import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Low-level HTTP client for the Rasa REST webhook.
///
/// Handles session ID generation, message sending, and JSON parsing.
/// All platform-specific base URL logic lives here.
class RasaService {
  /// Default: Android emulator loopback.
  /// Change to your machine's LAN IP for physical devices,
  static String baseUrl = 'http://10.217.211.1:5005';

  late String _senderId;

  RasaService() {
    _senderId = _generateSenderId();
  }

  String get senderId => _senderId;

  /// Generate a unique sender ID per session.
  static String _generateSenderId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999);
    return 'flutter_${ts}_$rand';
  }

  /// Reset the session (new sender ID = fresh Rasa context).
  void resetSession() {
    _senderId = _generateSenderId();
  }

  /// Send a message to Rasa and return the list of bot responses.
  ///
  /// [message]  — the user's text (e.g. "I have fever and headache").
  /// [metadata] — optional map sent once with the first message
  ///              (age, duration, severity from the assessment screen).
  Future<List<RasaResponse>> sendMessage(
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    final uri = Uri.parse('$baseUrl/webhooks/rest/webhook');

    final body = <String, dynamic>{
      'sender': _senderId,
      'message': message,
    };
    if (metadata != null && metadata.isNotEmpty) {
      body['metadata'] = metadata;
    }

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => RasaResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw RasaException(
        'Rasa returned status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Response model
// ---------------------------------------------------------------------------

/// A single message returned by the Rasa REST webhook.
///
/// The `custom` field maps to `json_message` set in the Rasa action server.
class RasaResponse {
  final String? recipientId;
  final String? text;
  final Map<String, dynamic>? custom;

  RasaResponse({this.recipientId, this.text, this.custom});

  factory RasaResponse.fromJson(Map<String, dynamic> json) {
    return RasaResponse(
      recipientId: json['recipient_id'] as String?,
      text: json['text'] as String?,
      custom: json['custom'] as Map<String, dynamic>?,
    );
  }

  // --- Convenience getters for structured responses ---

  bool get isEmergency => custom?['emergency'] == true;

  bool get isResult => custom?['type'] == 'result';

  bool get isQuestion => custom?['type'] == 'question';

  String get inputType => (custom?['input_type'] as String?) ?? 'yes_no';

  int get questionNumber => (custom?['question_number'] as int?) ?? 1;
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

class RasaException implements Exception {
  final String message;
  final int? statusCode;
  RasaException(this.message, {this.statusCode});
  @override
  String toString() => 'RasaException: $message';
}
