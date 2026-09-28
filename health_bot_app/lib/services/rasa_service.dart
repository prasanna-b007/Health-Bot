import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Low-level HTTP client for the Rasa REST webhook.
///
/// Handles session ID generation, message sending, and JSON parsing.
class RasaService {
  RasaService({http.Client? client}) : _client = client ?? http.Client() {
    _senderId = _generateSenderId();
  }

  final http.Client _client;
  late String _senderId;

  /// Backend host. Configured at build time so no machine-specific address is
  /// committed — see AppConfig and the README.
  static String get baseUrl => AppConfig.rasaBaseUrl;

  String get senderId => _senderId;

  /// A fresh conversation id.
  ///
  /// [Random.secure] rather than [Random]: the sender id is the only thing
  /// separating one user's triage session from another's on the server, and
  /// the default generator is seeded predictably enough that two devices
  /// starting together can collide — which would splice two people's symptoms
  /// into one conversation.
  static String _generateSenderId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Bound written as a literal, not `1 << 32`: dart2js constant-folds that
    // shift to 0 on web, and nextInt(0) throws RangeError. The VM evaluates it
    // as 2^32 and works, so the shift form fails only in the browser.
    final rand = Random.secure().nextInt(0x100000000);
    return 'flutter_${ts}_$rand';
  }

  /// Reset the session (new sender ID = fresh Rasa context).
  void resetSession() {
    _senderId = _generateSenderId();
  }

  /// Send a message to Rasa and return the list of bot responses.
  ///
  /// [metadata] carries age/duration/severity from the assessment screen so
  /// the backend can skip asking for them.
  ///
  /// Throws [RasaException]; the `kind` distinguishes a genuine connectivity
  /// problem from a malformed response, which the UI previously reported
  /// identically as "could not connect".
  Future<List<RasaResponse>> sendMessage(
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    // Rasa's --auth-token is checked as a `token` query parameter.
    final uri = Uri.parse('$baseUrl/webhooks/rest/webhook').replace(
      queryParameters: AppConfig.hasRasaAuthToken
          ? {'token': AppConfig.rasaAuthToken}
          : null,
    );
    final body = <String, dynamic>{
      'sender': _senderId,
      'message': message,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
    } on SocketException catch (e) {
      throw RasaException(
        'Could not reach the health server.',
        kind: RasaErrorKind.network,
        cause: e,
      );
    } catch (e) {
      throw RasaException(
        'Could not reach the health server.',
        kind: RasaErrorKind.network,
        cause: e,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RasaException(
        'This app is not authorised to reach the health server.',
        kind: RasaErrorKind.unauthorized,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw RasaException(
        'The health server returned an error (${response.statusCode}).',
        kind: RasaErrorKind.server,
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('expected a JSON array of messages');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RasaResponse.fromJson)
          .toList();
    } catch (e) {
      throw RasaException(
        'The health server sent an unreadable response.',
        kind: RasaErrorKind.parse,
        cause: e,
      );
    }
  }

  void dispose() => _client.close();
}

// ---------------------------------------------------------------------------
// Response model
// ---------------------------------------------------------------------------

/// A single message returned by the Rasa REST webhook.
///
/// The `custom` field maps to `json_message` set in the Rasa action server.
class RasaResponse {
  RasaResponse({this.recipientId, this.text, this.custom});

  final String? recipientId;
  final String? text;
  final Map<String, dynamic>? custom;

  factory RasaResponse.fromJson(Map<String, dynamic> json) {
    return RasaResponse(
      recipientId: json['recipient_id'] as String?,
      text: json['text'] as String?,
      custom: json['custom'] as Map<String, dynamic>?,
    );
  }

  String? get type => custom?['type'] as String?;

  bool get isEmergency => custom?['emergency'] == true || type == 'emergency';

  /// Which kind of red flag this is: "emergency" or "crisis".
  ///
  /// A medical emergency and a disclosed suicidal thought both stop triage,
  /// but they need opposite responses — a map of hospitals is the right answer
  /// to one and the wrong answer to the other. Absent on older backends, which
  /// default to the medical reading.
  String get redFlagCategory => (custom?['category'] as String?) ?? 'emergency';

  bool get isCrisis => custom?['crisis'] == true || redFlagCategory == 'crisis';

  bool get isResult => type == 'result';

  bool get isQuestion => type == 'question';

  /// The backend asks the app to run its own nearby-hospital search.
  bool get isHospitalRequest => type == 'hospitals';

  /// The backend could not understand the symptoms and wants a rephrase.
  bool get isClarification => type == 'clarification';

  String get inputType => (custom?['input_type'] as String?) ?? 'yes_no';

  int get questionNumber => (custom?['question_number'] as num?)?.toInt() ?? 1;
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

enum RasaErrorKind { network, server, parse, unauthorized }

class RasaException implements Exception {
  RasaException(
    this.message, {
    required this.kind,
    this.statusCode,
    this.cause,
  });

  final String message;
  final RasaErrorKind kind;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'RasaException($kind): $message';
}
