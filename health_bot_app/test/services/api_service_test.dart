import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/models/assessment_data.dart';
import 'package:health_bot_app/services/api_service.dart';
import 'package:health_bot_app/services/rasa_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds an ApiService whose HTTP layer returns [body] with [status].
ApiService serviceReturning(Object body, {int status = 200}) {
  final client = MockClient((_) async => http.Response(
        body is String ? body : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      ));
  return ApiService(rasa: RasaService(client: client));
}

ApiService serviceThrowing(Object error) {
  return ApiService(rasa: RasaService(client: MockClient((_) async => throw error)));
}

Map<String, dynamic> message(Map<String, dynamic> custom, {String text = ''}) => {
      'recipient_id': 'test',
      'text': text,
      'custom': custom,
    };

const resultPayload = {
  'type': 'result',
  'top_condition': 'Malaria',
  'confidence': 92,
  'confidence_band': 'likely',
  'confidence_label': 'Likely match',
  'risk': 'high',
  'risk_score': 70,
  'risk_factors': ['High symptom severity (8/10)'],
  'recommended_action': 'Seek medical attention within 24 hours.',
  'matched_symptoms': ['High Fever', 'Chills'],
  'ruled_out_symptoms': ['Vomiting'],
  'alternatives': [
    {'name': 'Dengue', 'confidence': 5, 'band': 'unclear'}
  ],
  'advice': ['Stay hydrated', 'Maintain good hygiene'],
  'specialist': {
    'name': 'General Physician',
    'description': 'Manages malaria.',
    'department': 'General Medicine',
    'priority': 'Immediate',
  },
  'disclaimer': 'This is not a medical diagnosis.',
};

void main() {
  group('result parsing', () {
    test('reads the full result payload', () async {
      final api = serviceReturning([message(resultPayload)]);
      final response = await api.answerQuestion(AnswerType.yes);

      final result = response.result;
      expect(result, isNotNull);
      expect(result!.conditionName, 'Malaria');
      expect(result.matchPercentage, 92);
      expect(result.confidenceBand, ConfidenceBand.likely);
      expect(result.confidenceLabel, 'Likely match');
      expect(result.riskLevel, 'high');
      expect(result.riskScore, 70);
      expect(result.matchedSymptoms, ['High Fever', 'Chills']);
      expect(result.ruledOutSymptoms, ['Vomiting']);
      expect(result.specialist.department, 'General Medicine');
      expect(result.advice, contains('Stay hydrated'));
    });

    test('finds the result even when other messages accompany it', () async {
      final api = serviceReturning([
        message(resultPayload),
        {'recipient_id': 'test', 'text': 'Was this helpful? (yes/no)'},
      ]);
      expect((await api.answerQuestion(AnswerType.yes)).result, isNotNull);
    });

    test('handles an inconclusive result', () async {
      final api = serviceReturning([
        message(const {
          'type': 'result',
          'top_condition': null,
          'confidence': 12,
          'confidence_band': 'unclear',
          'risk': 'low',
          'advice': ['Consult a doctor'],
        })
      ]);
      final result = (await api.answerQuestion(AnswerType.no)).result!;
      expect(result.isInconclusive, isTrue);
      expect(result.confidenceBand, ConfidenceBand.unclear);
    });
  });

  group('emergency parsing', () {
    test('detects the emergency payload', () async {
      final api = serviceReturning([
        message(const {'type': 'emergency', 'emergency': true, 'reason': 'Chest Pain'},
            text: 'Medical Emergency Detected')
      ]);
      final response = await api.answerQuestion(AnswerType.yes);
      expect(response.isEmergency, isTrue);
      expect(response.emergencyReason, 'Chest Pain');
    });

    test('emergency takes precedence over a question in the same batch', () async {
      final api = serviceReturning([
        message(const {'type': 'question', 'question': 'Do you have chills?'}),
        message(const {'type': 'emergency', 'emergency': true}),
      ]);
      expect((await api.answerQuestion(AnswerType.yes)).isEmergency, isTrue);
    });
  });

  group('question parsing', () {
    test('reads a follow-up question', () async {
      final api = serviceReturning([
        message(const {
          'type': 'question',
          'question': 'Are you also noticing any Chills?',
          'reason': 'Chills often occur with infections.',
          'question_number': 2,
          'estimated_total': 5,
          'input_type': 'yes_no',
        })
      ]);
      final question = (await api.answerQuestion(AnswerType.yes)).nextQuestion!;
      expect(question.text, 'Are you also noticing any Chills?');
      expect(question.questionNumber, 2);
      expect(question.inputType, 'yes_no');
      expect(question.reason, isNotEmpty);
    });

    test('reads a numeric intake question', () async {
      final api = serviceReturning([
        message(const {
          'type': 'question',
          'question': 'What is your age?',
          'input_type': 'number',
        })
      ]);
      expect((await api.sendText('hi')).nextQuestion!.inputType, 'number');
    });
  });

  group('error handling', () {
    test('a network failure is reported as a connection problem', () async {
      final api = serviceThrowing(const SocketExceptionStub());
      final response = await api.answerQuestion(AnswerType.yes);
      expect(response.hasError, isTrue);
      expect(response.errorMessage, contains('connection'));
    });

    test('a server error is not reported as a connection problem', () async {
      final api = serviceReturning('{}', status: 500);
      final response = await api.answerQuestion(AnswerType.yes);
      expect(response.hasError, isTrue);
      expect(response.errorMessage, contains('trouble'));
      expect(response.errorMessage, isNot(contains('connection')));
    });

    test('a malformed body is reported as unreadable, not as an outage', () async {
      final api = serviceReturning('not json at all');
      final response = await api.answerQuestion(AnswerType.yes);
      expect(response.hasError, isTrue);
      expect(response.errorMessage, contains('could not read'));
    });

    test('an empty batch is reported', () async {
      final api = serviceReturning(const []);
      expect((await api.answerQuestion(AnswerType.yes)).hasError, isTrue);
    });

    test('an unstructured reply surfaces the backend wording', () async {
      final api = serviceReturning([
        {'recipient_id': 'test', 'text': "I couldn't quite understand your symptoms."}
      ]);
      final response = await api.answerQuestion(AnswerType.yes);
      expect(response.errorMessage, contains('understand'));
    });
  });

  group('session', () {
    test('a session id is generated', () {
      expect(serviceReturning(const []).sessionId, startsWith('flutter_'));
    });

    test('resetting produces a new session id', () {
      final api = serviceReturning(const []);
      final before = api.sessionId;
      api.resetSession();
      expect(api.sessionId, isNot(before));
    });

    test('the sender id is sent with every message', () async {
      String? sentBody;
      final api = ApiService(
        rasa: RasaService(client: MockClient((request) async {
          sentBody = request.body;
          return http.Response('[]', 200);
        })),
      );
      await api.answerQuestion(AnswerType.yes);
      expect(jsonDecode(sentBody!)['sender'], api.sessionId);
    });

    test('assessment metadata travels with the first message', () async {
      String? sentBody;
      final api = ApiService(
        rasa: RasaService(client: MockClient((request) async {
          sentBody = request.body;
          return http.Response('[]', 200);
        })),
      );
      await api.sendSymptoms(
        AssessmentData(age: 22, duration: SymptomDuration.fourToSevenDays, severity: 8, symptoms: 'fever'),
      );
      final metadata = jsonDecode(sentBody!)['metadata'];
      expect(metadata['age'], 22);
      expect(metadata['duration'], 5);
      expect(metadata['severity'], 8);
    });

    test('answers map to the words the backend expects', () async {
      final sent = <String>[];
      final api = ApiService(
        rasa: RasaService(client: MockClient((request) async {
          sent.add(jsonDecode(request.body)['message'] as String);
          return http.Response('[]', 200);
        })),
      );
      await api.answerQuestion(AnswerType.yes);
      await api.answerQuestion(AnswerType.no);
      await api.answerQuestion(AnswerType.unsure);
      expect(sent, ['yes', 'no', "I'm not sure"]);
    });
  });
}

/// Stands in for a socket failure without importing dart:io into the test.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketExceptionStub';
}
