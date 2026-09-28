import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/screens/crisis_screen.dart';
import 'package:health_bot_app/util/crisis_lines.dart';
import 'package:health_bot_app/util/emergency_number.dart';
import 'package:health_bot_app/widgets/app_button.dart';
import 'package:health_bot_app/widgets/risk_bar.dart';
import 'package:health_bot_app/widgets/ui.dart';

/// Accessibility guarantees.
///
/// The app had no [Semantics] at all: every button built on [Pressable] was
/// announced as plain text, icon-only controls had no name, and the risk
/// meter read out as four anonymous rectangles. For an app whose users are
/// unwell — disproportionately older, disproportionately reaching for a phone
/// one-handed — that is not a nice-to-have.
///
/// Flutter ships the real checks as [meetsGuideline]; these run them rather
/// than re-implementing weaker versions by hand.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('roles and labels', () {
    testWidgets('a button is announced as a button', (tester) async {
      await tester.pumpWidget(
        wrap(AppButton(label: 'Continue', onPressed: () {})),
      );
      expect(
        tester.getSemantics(find.byType(AppButton)),
        isSemantics(isButton: true, isEnabled: true, label: 'Continue'),
      );
    });

    testWidgets('a disabled button says so', (tester) async {
      await tester.pumpWidget(
        wrap(const AppButton(label: 'Continue', onPressed: null)),
      );
      expect(
        tester.getSemantics(find.byType(AppButton)),
        isSemantics(isButton: true, isEnabled: false),
      );
    });

    testWidgets('an icon-only button carries a name', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Back'),
        findsWidgets,
        reason: 'the way out of a screen must have a name',
      );
    });

    testWidgets('the risk meter reads as one value, not four shapes', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const RiskBar(riskLevel: RiskLevel.high)));
      expect(
        find.bySemanticsLabel(RegExp('Risk level: High, 3 out of 4')),
        findsOneWidget,
      );
    });
  });

  group('guidelines', () {
    testWidgets('tap targets are large enough', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(label: 'Continue', onPressed: () {}),
              AppIconButton(
                icon: Icons.share,
                tooltip: 'Share',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('interactive elements are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: CrisisScreen(
            line: CrisisLine(
              name: 'Samaritans',
              number: '116123',
              countryCode: 'GB',
            ),
            emergency: EmergencyNumber(number: '999', countryCode: 'GB'),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text contrast is sufficient on the crisis screen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: CrisisScreen(
            line: CrisisLine(
              name: 'Samaritans',
              number: '116123',
              countryCode: 'GB',
            ),
            emergency: EmergencyNumber(number: '999', countryCode: 'GB'),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('text scaling', () {
    testWidgets('the crisis screen survives 200% text', (tester) async {
      // Someone who has set their phone to the largest text is exactly the
      // person this screen must not break for.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: CrisisScreen(
              line: CrisisLine(
                name: 'Samaritans',
                number: '116123',
                countryCode: 'GB',
              ),
              emergency: EmergencyNumber(number: '999', countryCode: 'GB'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Samaritans'), findsOneWidget);
    });
  });
}
