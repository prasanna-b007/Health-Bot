// Smoke tests for the app shell.
//
// This file used to be the unmodified Flutter counter template, asserting on a
// "+" button the app has never had -- so `flutter test` was red and nobody ran
// it.
//
// Note on pumping: the Nocturne UI keeps a heartbeat running -- the ECG trace
// and the live dot repeat forever by design -- so `pumpAndSettle` never
// returns on any screen that shows one. These tests advance the clock by
// explicit durations instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/main.dart';
import 'package:health_bot_app/services/health_store.dart';
import 'package:health_bot_app/models/health_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash dwell plus its transition into the home screen.
const _pastSplash = Duration(milliseconds: 1500);
const _pastTransition = Duration(milliseconds: 700);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HealthStore.instance.reset();
  });

  testWidgets('the app builds and shows the splash screen', (tester) async {
    await tester.pumpWidget(const HealthBotApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Health-Bot'), findsOneWidget);

    // Let the splash's scheduled navigation run so the test does not end with
    // a pending timer.
    await tester.pump(_pastSplash);
    await tester.pump(_pastTransition);
  });

  testWidgets('the app reaches the profile screen after the splash on first run',
      (tester) async {
    await tester.pumpWidget(const HealthBotApp());
    await tester.pump(_pastSplash);
    await tester.pump(_pastTransition);

    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('the app reaches the home screen if profile is configured',
      (tester) async {
    // Configure profile
    final p = const HealthProfile(name: 'Test', age: 30);
    await HealthStore.instance.saveProfile(p);

    await tester.pumpWidget(const HealthBotApp());
    await tester.pump(_pastSplash);
    await tester.pump(_pastTransition);

    expect(find.text('Check my symptoms'), findsOneWidget);
    expect(find.text('Emergency help'), findsOneWidget);
  });

  testWidgets('tapping symptom check opens the assessment form',
      (tester) async {
    // Configure profile so it goes to home screen
    final p = const HealthProfile(name: 'Test', age: 30);
    await HealthStore.instance.saveProfile(p);

    await tester.pumpWidget(const HealthBotApp());
    await tester.pump(_pastSplash);
    await tester.pump(_pastTransition);

    await tester.tap(find.text('Check my symptoms'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Three quick things'), findsOneWidget);
    expect(find.text('Check my symptoms'), findsNothing);
  });
}
