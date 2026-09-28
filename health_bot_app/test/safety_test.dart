// The three safety behaviours, tested at the level that would actually fail a
// user: which number gets dialled, whether an unreachable server can swallow a
// red flag, and whether the profile the app collects reaches the risk engine.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/main.dart';
import 'package:health_bot_app/models/assessment_data.dart';
import 'package:health_bot_app/screens/symptom_input_screen.dart';
import 'package:health_bot_app/services/api_service.dart';
import 'package:health_bot_app/models/health_profile.dart';
import 'package:health_bot_app/services/health_store.dart';
import 'package:health_bot_app/services/red_flags.dart';
import 'package:health_bot_app/util/emergency_number.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An ApiService whose server is always unreachable — the situation the
/// offline check exists for.
class _OfflineApi extends ApiService {
  int calls = 0;
  List<String> lastConditions = const [];

  @override
  Future<TriageResponse> sendSymptoms(
    AssessmentData data, {
    List<String> conditions = const [],
  }) async {
    calls++;
    lastConditions = conditions;
    return TriageResponse(
      isEmergency: false,
      errorMessage:
          'Could not reach the health server. Please check your connection.',
    );
  }
}

void main() {
  group('emergency number', () {
    test('dials the local medical number, not a hardcoded 112', () {
      // The regression this whole file exists for: 112 is correct in the EU
      // and India and wrong in most of the anglosphere and Asia.
      expect(EmergencyNumber.forCountry('US').number, '108');
      expect(EmergencyNumber.forCountry('GB').number, '999');
      expect(EmergencyNumber.forCountry('AU').number, '000');
      expect(EmergencyNumber.forCountry('JP').number, '119');
      expect(EmergencyNumber.forCountry('IN').number, '108');
    });

    test('prefers the ambulance line where a country runs a separate one', () {
      expect(EmergencyNumber.forCountry('BR').number, '192'); // SAMU
      expect(EmergencyNumber.forCountry('CN').number, '120'); // ambulance
      expect(EmergencyNumber.forCountry('IL').number, '101'); // MDA
    });

    test('falls back to 112 for an unknown or missing country', () {
      // 112 is the GSM standard and is routed by most networks worldwide, so
      // it is the right thing to dial when the country is genuinely unknown.
      for (final code in [null, '', '  ', 'ZZ', 'not-a-country']) {
        final resolved = EmergencyNumber.forCountry(code);
        expect(resolved.number, '112', reason: 'code=$code');
        expect(resolved.isKnownCountry, isFalse, reason: 'code=$code');
      }
    });

    test('is case insensitive about the country code', () {
      expect(EmergencyNumber.forCountry('us').number, '108');
      expect(EmergencyNumber.forCountry('Gb').number, '999');
    });

    test('resolves from the first locale that names a known country', () {
      final resolved = EmergencyNumber.resolve(locales: const [
        Locale('en'), // no country
        Locale('en', 'ZZ'), // unknown country
        Locale('en', 'AU'),
      ]);
      expect(resolved.number, '000');
      expect(resolved.countryCode, 'AU');
    });

    test('resolves to the fallback when no locale names a known country', () {
      final resolved =
          EmergencyNumber.resolve(locales: const [Locale('eo'), Locale('en')]);
      expect(resolved.number, '112');
      expect(resolved.isKnownCountry, isFalse);
    });

    test('every mapped number is dialable digits', () {
      // A stray space or dash would produce a tel: URI that silently fails.
      for (final entry in EmergencyNumber.byCountry.entries) {
        expect(entry.value, matches(RegExp(r'^\d{2,5}$')),
            reason: '${entry.key} -> ${entry.value}');
      }
    });
  });

  group('offline red flags', () {
    test('catches the phrasings that matter', () {
      for (final text in [
        'crushing chest pain',
        'I have severe chest pain and nausea',
        'cannot breathe properly',
        'my throat is closing',
        'worst headache of life',
      ]) {
        expect(RedFlags.has(text), isTrue, reason: text);
      }
    });

    test("matches regardless of apostrophes and casing", () {
      // The server normalises the same way; "can't" and "cant" must agree,
      // because a word-boundary regex on the raw text is exactly what used to
      // let the apostrophe defeat the match.
      expect(RedFlags.has("I can't breathe"), isTrue);
      expect(RedFlags.has('I CANT BREATHE'), isTrue);
      expect(RedFlags.has('Cant  Breathe'), isTrue);
    });

    test('does not fire on ordinary symptom descriptions', () {
      // A safety net that cries wolf gets ignored, which costs more than it
      // saves.
      for (final text in [
        'fever and a headache since Sunday',
        'sore throat and a blocked nose',
        'stomach ache after eating',
        'mild cough and tiredness',
        '',
      ]) {
        expect(RedFlags.has(text), isFalse, reason: text);
      }
    });

    test('names the phrase it matched so the reason can be shown', () {
      expect(RedFlags.findIn('sudden chest pain'), 'chest pain');
      final reason = RedFlags.reasonFor('chest pain');
      expect(reason, contains('chest pain'));
      // The user must be told this was a fallback, not a completed assessment.
      expect(reason.toLowerCase(), contains('could not be reached'));
    });

    test('mirrors the server list without drifting into vagueness', () {
      // Every phrase must be normalised already, or it can never match
      // normalised input.
      for (final phrase in RedFlags.phrases) {
        expect(phrase, RedFlags.normalize(phrase), reason: phrase);
        expect(phrase.length, greaterThan(4), reason: phrase);
      }
    });
  });

  group('offline fallback, end to end', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HealthStore.instance.reset();
    });

    Future<_OfflineApi> pumpSymptoms(WidgetTester tester, String text) async {
      final api = _OfflineApi();
      await tester.pumpWidget(MaterialApp(
        theme: HealthBotApp.theme,
        home: SymptomInputScreen(
          data: AssessmentData(age: 40, severity: 5),
          apiService: api,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pump();
      await tester.tap(find.text('Analyse symptoms'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return api;
    }

    testWidgets('an unreachable server cannot swallow a red flag',
        (tester) async {
      await pumpSymptoms(tester, 'crushing chest pain and I cannot breathe');

      // The user must land on emergency guidance, not a connection error.
      expect(find.text('Seek care now'), findsOneWidget);
      expect(find.textContaining('chest pain'), findsWidgets);
    });

    testWidgets('the emergency screen offers a dialable local number',
        (tester) async {
      await pumpSymptoms(tester, 'severe chest pain');

      final expected = EmergencyNumber.resolve().number;
      expect(find.text('Call $expected'), findsOneWidget);
    });

    testWidgets('an ordinary description still shows the network error',
        (tester) async {
      await pumpSymptoms(tester, 'mild sore throat since yesterday');

      // No red flag means no escalation — the fallback only ever escalates.
      expect(find.text('Seek care now'), findsNothing);
      expect(find.textContaining('Could not reach'), findsOneWidget);
    });
  });

  group('profile reaches the risk engine', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HealthStore.instance.reset();
    });

    testWidgets('stored conditions are sent with the assessment',
        (tester) async {
      await HealthStore.instance.saveProfile(
        const HealthProfile(age: 64, conditions: ['Asthma'], allergies: ['Penicillin']),
      );

      final api = _OfflineApi();
      await tester.pumpWidget(MaterialApp(
        theme: HealthBotApp.theme,
        home: SymptomInputScreen(
          data: AssessmentData(age: 64, severity: 7),
          apiService: api,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, 'fever and cough');
      await tester.pump();
      await tester.tap(find.text('Analyse symptoms'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(api.calls, 1);
      // The regression: conditions used to be collected and then discarded.
      expect(api.lastConditions, ['Asthma']);
    });

    testWidgets('no profile means nothing extra is sent', (tester) async {
      final api = _OfflineApi();
      await tester.pumpWidget(MaterialApp(
        theme: HealthBotApp.theme,
        home: SymptomInputScreen(
          data: AssessmentData(age: 30, severity: 4),
          apiService: api,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, 'headache');
      await tester.pump();
      await tester.tap(find.text('Analyse symptoms'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(api.lastConditions, isEmpty);
    });
  });
}
