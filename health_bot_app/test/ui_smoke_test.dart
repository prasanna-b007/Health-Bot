import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_bot_app/main.dart';
import 'package:health_bot_app/models/assessment_data.dart';
import 'package:health_bot_app/models/assessment_record.dart';
import 'package:health_bot_app/models/health_profile.dart';
import 'package:health_bot_app/screens/assessment_form_screen.dart';
import 'package:health_bot_app/screens/dynamic_triage_screen.dart';
import 'package:health_bot_app/screens/history_screen.dart';
import 'package:health_bot_app/screens/hospital_finder_screen.dart';
import 'package:health_bot_app/screens/home_screen.dart';
import 'package:health_bot_app/screens/profile_screen.dart';
import 'package:health_bot_app/screens/results_screen.dart';
import 'package:health_bot_app/screens/symptom_input_screen.dart';
import 'package:health_bot_app/services/api_service.dart';
import 'package:health_bot_app/services/health_store.dart';

/// Renders every screen of the redesigned UI.
///
/// These are deliberately shallow: they do not assert on layout details, which
/// would break on every design tweak. What they catch is the class of failure
/// that only appears at paint time and that the analyzer cannot see — an
/// unbounded constraint, a baseline a box cannot report, a CustomPainter given
/// a zero size — on screens a person would otherwise have to click through by
/// hand to discover.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // The store is a singleton, so it has to be put back to empty between
    // tests or one test's saved profile becomes the next test's fixture.
    await HealthStore.instance.reset();
  });

  /// Pumps [child] inside the real app theme, since several widgets read
  /// colours and text styles through it.
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: HealthBotApp.theme,
      home: child,
    ));
    // One frame past the entrance springs and staggered reveals.
    await tester.pump(const Duration(milliseconds: 600));
  }

  AssessmentResult sampleResult({String risk = 'high'}) => AssessmentResult(
        conditionName: 'Influenza',
        matchPercentage: 78,
        confidenceBand: ConfidenceBand.likely,
        alternateMatches: const ['Common cold', 'COVID-19'],
        riskLevel: risk,
        riskScore: 7,
        riskFactors: const ['Age over 60'],
        advice: '• Rest and stay hydrated\n• Monitor your temperature',
        recommendedAction: 'See a doctor within 24 hours',
        matchedSymptoms: const ['fever', 'cough'],
        ruledOutSymptoms: const ['rash'],
      );

  AssessmentData sampleData() => AssessmentData(
        age: 64,
        duration: SymptomDuration.fourToSevenDays,
        severity: 7,
        symptoms: 'fever and cough',
      );

  testWidgets('home renders with an empty store', (tester) async {
    await show(tester, const HomeScreen());

    expect(find.text('Check my symptoms'), findsOneWidget);
    expect(find.text('Emergency help'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home greets by name and lists saved assessments',
      (tester) async {
    await HealthStore.instance
        .saveProfile(const HealthProfile(name: 'Prasanna', age: 30));
    await HealthStore.instance.addRecord(
      AssessmentRecord.from(data: sampleData(), result: sampleResult()),
    );

    await show(tester, const HomeScreen());

    expect(find.textContaining('Prasanna'), findsWidgets);
    expect(find.text('Influenza'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assessment form prefills age from the profile', (tester) async {
    await HealthStore.instance.saveProfile(const HealthProfile(age: 41));
    await show(tester, const AssessmentFormScreen());

    // Prefilled and labelled as such — the user still confirms it by
    // continuing, but they do not have to retype it.
    expect(find.text('Three quick things'), findsOneWidget);
    expect(find.text('From profile'), findsOneWidget);
    expect(find.widgetWithText(TextField, '41'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assessment form asks for age when there is no profile',
      (tester) async {
    await show(tester, const AssessmentFormScreen());

    expect(find.text('From profile'), findsNothing);
    // No profile must mean a genuinely empty field, never an inherited number.
    expect(find.widgetWithText(TextField, 'e.g. 34'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('symptom input renders and quick-add edits the description',
      (tester) async {
    await show(tester, SymptomInputScreen(data: sampleData()));

    await tester.tap(find.text('Fever'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(TextField, 'fever'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('results renders every risk level', (tester) async {
    for (final risk in ['low', 'moderate', 'high', 'emergency']) {
      await show(
        tester,
        ResultsScreen(data: sampleData(), result: sampleResult(risk: risk)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Influenza'), findsOneWidget, reason: 'risk=$risk');
      expect(tester.takeException(), isNull, reason: 'risk=$risk');
    }
  });

  testWidgets('an inconclusive result does not render a condition card',
      (tester) async {
    await show(
      tester,
      ResultsScreen(
        data: sampleData(),
        result: AssessmentResult(
          conditionName: 'Unknown',
          matchPercentage: 0,
          alternateMatches: const [],
          riskLevel: 'low',
          advice: 'Rest.',
        ),
      ),
    );

    expect(find.text('No clear match'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an archived result replays without re-saving', (tester) async {

    final record =
        AssessmentRecord.from(data: sampleData(), result: sampleResult());
    await show(tester, ResultsScreen.archived(record: record));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Influenza'), findsOneWidget);
    // Viewing history must not append a duplicate entry to it.
    expect(HealthStore.instance.history, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history shows an empty state, then entries', (tester) async {

    await show(tester, const HistoryScreen());
    expect(find.text('Nothing recorded yet'), findsOneWidget);

    await HealthStore.instance.addRecord(
      AssessmentRecord.from(data: sampleData(), result: sampleResult()),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Influenza'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the interview renders a question and its reason',
      (tester) async {
    await show(
      tester,
      DynamicTriageScreen(
        data: sampleData(),
        apiService: ApiService(),
        currentQuestion: TriageQuestion(
          id: 'malaise',
          text: 'Along with those, do you also have **malaise**?',
          reason: 'General malaise reflects overall severity.',
          questionNumber: 2,
          estimatedTotal: 5,
        ),
      ),
    );

    expect(find.text('Question 2 of about 5'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The reason is collapsed until asked for.
    await tester.tap(find.text('Why we ask'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hospital finder renders while it has no location',
      (tester) async {
    // No location service in a test binding, so this exercises the searching
    // state and then whichever failure state the platform channel produces —
    // both of which are screens a user can land on.
    await show(tester, const HospitalFinderScreen(emergencyReason: 'Test.'));
    expect(find.text('Seek care now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile saves an edit to the store', (tester) async {
    await show(tester, const ProfileScreen());

    // The first field on the screen is the name.
    await tester.enterText(find.byType(TextField).first, 'Prasanna');
    await tester.pump(const Duration(milliseconds: 200));

    // Save sits below the fold, and a ListView does not build what it has not
    // scrolled to.
    await tester.scrollUntilVisible(
      find.text('Save profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(HealthStore.instance.profile.name, 'Prasanna');
    expect(tester.takeException(), isNull);
  });
}
