import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/screens/assessment_form_screen.dart';
import 'package:health_bot_app/theme/colors.dart';
import 'package:health_bot_app/widgets/app_button.dart';

Future<void> pumpForm(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: AssessmentFormScreen()));
  await tester.pumpAndSettle();
}

AppButton continueButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, 'Continue'));

bool continueEnabled(WidgetTester tester) =>
    continueButton(tester).onPressed != null;

Future<void> enterAge(WidgetTester tester, String age) async {
  await tester.enterText(find.byType(TextField), age);
  await tester.pump();
}

void main() {
  group('age field', () {
    testWidgets('starts empty rather than prefilled', (tester) async {
      await pumpForm(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      // Regression: the field opened with 22 already in it, so a user could
      // continue without ever entering their own age.
      expect(field.controller!.text, isEmpty);
      expect(find.text('e.g. 34'), findsOneWidget);
    });

    testWidgets('Continue is disabled until an age is entered', (tester) async {
      await pumpForm(tester);
      expect(continueEnabled(tester), isFalse);

      await enterAge(tester, '34');
      expect(continueEnabled(tester), isTrue);
    });

    testWidgets('clearing the age disables Continue again', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '34');
      expect(continueEnabled(tester), isTrue);

      // Previously the field kept the last parseable value on clear, so an
      // empty box still submitted a stale age.
      await enterAge(tester, '');
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets('an implausible age is rejected', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '999');
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets('letters cannot be typed into the field', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, 'abc');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets('the age is capped at three digits', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '12345');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, lessThanOrEqualTo(3));
    });

    testWidgets('no error is shown before the field is touched', (tester) async {
      await pumpForm(tester);
      expect(find.text('Please enter your age.'), findsNothing);
    });

    testWidgets('an error appears once an invalid age is entered and left',
        (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '150');
      // Move focus away to mark the field as visited.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.textContaining('120'), findsOneWidget);
    });

    testWidgets('boundary ages are accepted', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '0');
      expect(continueEnabled(tester), isTrue);
      await enterAge(tester, '120');
      expect(continueEnabled(tester), isTrue);
    });
  });

  group('age context note', () {
    testWidgets('explains the effect for an infant', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '1');
      expect(find.textContaining('Infants'), findsOneWidget);
    });

    testWidgets('explains the effect for an older adult', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '72');
      expect(find.text('Age is treated as an added risk factor.'), findsOneWidget);
    });

    testWidgets('stays quiet for a typical adult age', (tester) async {
      await pumpForm(tester);
      await enterAge(tester, '34');
      expect(find.textContaining('Infants'), findsNothing);
      expect(find.textContaining('children'), findsNothing);
    });
  });

  group('duration options', () {
    testWidgets('every duration option is offered', (tester) async {
      await pumpForm(tester);
      for (final label in ['1 day', '2-3 days', '4-7 days', '> 1 week']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('selecting a duration lights it and dims the rest',
        (tester) async {
      await pumpForm(tester);
      await tester.ensureVisible(find.text('> 1 week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('> 1 week'));
      await tester.pumpAndSettle();

      // Selection is carried by colour rather than an added tick, so that is
      // what gets asserted: exactly one option is lit, and it is this one.
      Color? colourOf(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;

      expect(colourOf('> 1 week'), AppColors.signal);
      for (final other in ['1 day', '2-3 days', '4-7 days']) {
        expect(colourOf(other), isNot(AppColors.signal), reason: other);
      }
    });
  });
}
