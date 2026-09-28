import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../util/crisis_lines.dart';
import '../util/emergency_number.dart';
import '../widgets/app_button.dart';
import '../widgets/ui.dart';

/// Shown when someone discloses suicidal thoughts or self-harm.
///
/// This screen exists because the app previously had no answer for this. The
/// backend matched "I want to end my life" with the same keyword list as
/// chest pain, and the app responded by opening a map of nearby hospitals —
/// handing the most difficult thing a person can say to a search result.
///
/// What is different here is deliberate, and mostly about restraint:
///
///  - **No triage.** There are no questions, no risk score, no condition, no
///    "was this helpful?". The assessment is over. Continuing to interrogate
///    someone in this position would be the app serving itself.
///  - **The disclosure is never repeated back.** Other escalations name the
///    phrase that triggered them; this one does not. Seeing your own words
///    quoted by software is not a neutral act.
///  - **One clear action.** Calling the crisis line is the only primary
///    button. The emergency number stays available for immediate danger, but
///    below, because an ambulance is not the usual next step.
///  - **Not red.** Every other escalation in this app uses [AppColors.ember].
///    Alarm is the right register for a heart attack and the wrong one here,
///    so this screen is calm: the accent is [AppColors.pulse], and the page
///    looks like somewhere to sit down rather than somewhere to run.
class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key, this.line, this.emergency});

  /// Injectable for tests; resolves from the device locale otherwise.
  final CrisisLine? line;
  final EmergencyNumber? emergency;

  @override
  Widget build(BuildContext context) {
    final crisis = line ?? CrisisLine.resolve();
    final emergencyNumber = emergency ?? EmergencyNumber.resolve();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: 'Support',
        leading: AppIconButton(
          icon: Icons.close_rounded,
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          tooltip: 'Close and return home',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space20,
            AppTheme.space24,
            AppTheme.space20,
            AppTheme.space32,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                'You matter, and help is available',
                style: AppText.h1,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Text(
              'Thank you for saying something. Talking to someone trained for '
              'this can help, and reaching out is not an overreaction.',
              style: AppText.body,
            ),
            const SizedBox(height: AppTheme.space24),

            _CrisisLineCard(line: crisis),

            const SizedBox(height: AppTheme.space16),
            AppCard(
              accent: AppColors.pulse,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    'While you wait',
                    color: AppColors.pulse,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  ..._waitingSteps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7, right: 10),
                            child: Dot(color: AppColors.pulse, size: 5),
                          ),
                          Expanded(child: Text(step, style: AppText.body)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.space24),
            Text(
              'If you are in immediate physical danger',
              style: AppText.label,
            ),
            const SizedBox(height: AppTheme.space8),
            AppButton(
              label: 'Call emergency services (${emergencyNumber.number})',
              icon: Icons.emergency_outlined,
              variant: AppButtonVariant.secondary,
              accent: AppColors.ember,
              onPressed: () => _dial(emergencyNumber.number),
            ),
            const SizedBox(height: AppTheme.space20),
            Text(
              'This app is not a counsellor and does not store what you typed. '
              'The people on the other end of these lines are trained, and the '
              'call is free and confidential.',
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _waitingSteps = [
    'Try to stay with someone, or ask a person you trust to come over',
    'Move anything you could use to hurt yourself out of reach, or ask '
        'someone else to hold it for now',
    'You do not have to explain everything to reach out — "I am struggling" '
        'is enough to start',
  ];

  static Future<void> _dial(String number) async {
    if (number.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> _openDirectory() async {
    final uri = Uri.parse('https://findahelpline.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// The crisis line itself, or an honest admission that we do not know it.
class _CrisisLineCard extends StatelessWidget {
  const _CrisisLineCard({required this.line});

  final CrisisLine line;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.signal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(line.name, style: AppText.h3)),
          const SizedBox(height: AppTheme.space4),
          Text(line.hours, style: AppText.caption),
          const SizedBox(height: AppTheme.space16),
          if (line.isKnown) ...[
            AppButton(
              label: 'Call ${line.number}',
              icon: Icons.call_rounded,
              onPressed: () => CrisisScreen._dial(line.number),
            ),
            if (line.hasTextOption) ...[
              const SizedBox(height: AppTheme.space12),
              Semantics(
                label: 'Text option: ${line.textOption}',
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Expanded(child: Text(line.textOption, style: AppText.body)),
                  ],
                ),
              ),
            ],
          ] else ...[
            // No number for this country. Saying so beats dialling a wrong
            // one at the worst possible moment.
            Text(
              'We could not work out which service covers your country. This '
              'directory lists crisis lines worldwide.',
              style: AppText.body,
            ),
            const SizedBox(height: AppTheme.space12),
            AppButton(
              label: 'Open findahelpline.com',
              icon: Icons.open_in_new_rounded,
              onPressed: CrisisScreen._openDirectory,
            ),
          ],
        ],
      ),
    );
  }
}
