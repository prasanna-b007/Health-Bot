
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/models/assessment_data.dart';
import 'package:health_bot_app/screens/crisis_screen.dart';
import 'package:health_bot_app/services/api_service.dart';
import 'package:health_bot_app/services/rasa_service.dart';
import 'package:health_bot_app/services/red_flags.dart';
import 'package:health_bot_app/util/crisis_lines.dart';
import 'package:health_bot_app/util/emergency_number.dart';

/// A crisis disclosure must never be answered with a map of hospitals.
///
/// The cases here guard the distinction end to end: the backend marks the
/// category, the API layer carries it, and the app sends the user somewhere
/// different because of it.
void main() {
  group('CrisisLine resolution', () {
    test('resolves a known country from the locale', () {
      final line = CrisisLine.resolve(locales: const [Locale('en', 'US')]);
      expect(line.isKnown, isTrue);
      expect(line.number, '988');
    });

    test('skips locales it does not recognise', () {
      final line = CrisisLine.resolve(
        locales: const [Locale('en', 'ZZ'), Locale('en', 'GB')],
      );
      expect(line.countryCode, 'GB');
    });

    test('admits when it does not know the country', () {
      final line = CrisisLine.resolve(locales: const [Locale('en', 'ZZ')]);
      expect(line.isKnown, isFalse);
      expect(line.number, isEmpty);
    });

    test('never invents a number for an unknown country', () {
      // Dialling a guessed number at this moment is worse than saying so.
      expect(CrisisLine.unknown.number, isEmpty);
      expect(CrisisLine.forCountry('ZZ').number, isEmpty);
    });

    test('every listed line has a name and digits only', () {
      for (final entry in CrisisLine.byCountry.entries) {
        expect(entry.value.name, isNotEmpty, reason: entry.key);
        expect(entry.value.number, isNotEmpty, reason: entry.key);
        expect(
          RegExp(r'^[0-9]+$').hasMatch(entry.value.number),
          isTrue,
          reason: '${entry.key} is not dialable: ${entry.value.number}',
        );
        expect(entry.value.countryCode, entry.key);
      }
    });
  });

  group('crisis responses', () {
    RasaResponse crisis() => RasaResponse(
      text: 'You matter, and help is available right now.',
      custom: const {
        'type': 'emergency',
        'emergency': true,
        'category': 'crisis',
        'crisis': true,
        'reason': null,
      },
    );

    RasaResponse medical() => RasaResponse(
      text: 'Medical Emergency Detected',
      custom: const {
        'type': 'emergency',
        'emergency': true,
        'category': 'emergency',
        'reason': 'Chest Pain',
      },
    );

    test('a crisis is recognised as a crisis', () {
      expect(crisis().isCrisis, isTrue);
      expect(crisis().isEmergency, isTrue);
    });

    test('a medical emergency is not a crisis', () {
      expect(medical().isCrisis, isFalse);
      expect(medical().isEmergency, isTrue);
    });

    test('an older backend without a category still escalates', () {
      final legacy = RasaResponse(
        custom: const {'type': 'emergency', 'emergency': true},
      );
      expect(legacy.isEmergency, isTrue);
      expect(legacy.isCrisis, isFalse);
    });

    test('the API layer carries the crisis flag', () {
      final parsed = ApiService().parseForTest([crisis()]);
      expect(parsed.isEmergency, isTrue);
      expect(parsed.isCrisis, isTrue);
    });

    test('a crisis never echoes the disclosure back', () {
      // The backend withholds the matched phrase; this makes sure the app
      // cannot substitute the raw message text for it.
      final parsed = ApiService().parseForTest([crisis()]);
      expect(parsed.emergencyReason, isNull);
    });

    test('a medical emergency still names its reason', () {
      final parsed = ApiService().parseForTest([medical()]);
      expect(parsed.isCrisis, isFalse);
      expect(parsed.emergencyReason, 'Chest Pain');
    });
  });

  group('CrisisScreen', () {
    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('shows the local line and how to reach it', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CrisisScreen(
            line: CrisisLine(
              name: 'Samaritans',
              number: '116123',
              countryCode: 'GB',
              textOption: 'Text SHOUT to 85258',
            ),
            emergency: EmergencyNumber(number: '999', countryCode: 'GB'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Samaritans'), findsOneWidget);
      expect(find.text('Call 116123'), findsOneWidget);
      expect(find.text('Text SHOUT to 85258'), findsOneWidget);
    });

    testWidgets('keeps emergency services as the secondary option', (
      tester,
    ) async {
      // Tall surface: the emergency option sits below the crisis line on
      // purpose, and a default 800px test window never lays it out.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          const CrisisScreen(
            line: CrisisLine(
              name: 'Samaritans',
              number: '116123',
              countryCode: 'GB',
            ),
            emergency: EmergencyNumber(number: '999', countryCode: 'GB'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Call emergency services (999)'), findsOneWidget);
    });

    testWidgets('offers a directory when the country is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CrisisScreen(
            line: CrisisLine.unknown,
            emergency: EmergencyNumber.fallback,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Open findahelpline.com'), findsOneWidget);
    });

    testWidgets('asks the user nothing', (tester) async {
      // Triage is over. A screen that kept interrogating someone here would
      // be the app serving itself.
      await tester.pumpWidget(
        wrap(
          const CrisisScreen(
            line: CrisisLine.unknown,
            emergency: EmergencyNumber.fallback,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Was this helpful'), findsNothing);
      expect(find.textContaining('?'), findsNothing);
    });
  });

  group('offline red flags', () {
    test('a crisis disclosure is not a medical emergency', () {
      // With no network there is no server to correct this, so the offline
      // net has to make the same distinction the server does.
      expect(RedFlags.hasCrisis('I want to end my life'), isTrue);
      expect(RedFlags.findIn('I want to end my life'), isNull);
    });

    test('a medical emergency is still caught offline', () {
      expect(RedFlags.findIn('crushing chest pain'), isNotNull);
      expect(RedFlags.hasCrisis('crushing chest pain'), isFalse);
    });

    test('the two lists do not overlap', () {
      final overlap = RedFlags.phrases.toSet().intersection(
        RedFlags.crisisPhrases.toSet(),
      );
      expect(overlap, isEmpty);
    });

    test('ordinary symptoms trip neither', () {
      expect(RedFlags.has('I have a headache and a mild fever'), isFalse);
      expect(RedFlags.hasCrisis('I have a headache and a mild fever'), isFalse);
    });
  });

  group('session ids', () {
    test('are not repeated across services', () {
      final ids = List.generate(200, (_) => RasaService().senderId).toSet();
      expect(ids.length, 200);
    });

    test('change when the session is reset', () {
      final service = RasaService();
      final first = service.senderId;
      service.resetSession();
      expect(service.senderId, isNot(first));
    });
  });

  group('Disposition', () {
    test('parses every backend code', () {
      expect(Disposition.fromString('emergency'), Disposition.emergency);
      expect(Disposition.fromString('urgent_today'), Disposition.urgentToday);
      expect(
        Disposition.fromString('see_doctor_soon'),
        Disposition.seeDoctorSoon,
      );
      expect(Disposition.fromString('self_care'), Disposition.selfCare);
    });

    test('an unknown code never invents urgency', () {
      expect(Disposition.fromString('banana'), Disposition.selfCare);
      expect(Disposition.fromString(null), Disposition.selfCare);
    });

    test('urgency is ordered', () {
      expect(
        Disposition.emergency.urgency,
        greaterThan(Disposition.urgentToday.urgency),
      );
      expect(
        Disposition.urgentToday.urgency,
        greaterThan(Disposition.seeDoctorSoon.urgency),
      );
      expect(
        Disposition.seeDoctorSoon.urgency,
        greaterThan(Disposition.selfCare.urgency),
      );
    });
  });
}
