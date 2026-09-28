import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/assessment_data.dart';
import '../models/assessment_record.dart';
import '../motion/pressable.dart';
import '../services/health_store.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../util/moment.dart';
import '../widgets/app_button.dart';
import '../widgets/ui.dart';
import '../widgets/risk_bar.dart';
import '../widgets/stage_tracker.dart';
import 'hospital_finder_screen.dart';

/// The outcome of an assessment.
///
/// The same screen serves a result that has just arrived and one replayed from
/// history — [ResultsScreen.archived] — so a saved assessment is not a
/// second-class summary of the real thing. The only differences are the stage
/// tracker (nothing is in progress) and the timestamp in the header.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.data, required this.result})
    : takenAt = null,
      isArchived = false;

  /// Replays a stored assessment.
  ResultsScreen.archived({super.key, required AssessmentRecord record})
    : data = record.toData(),
      result = record.toResult(),
      takenAt = record.takenAt,
      isArchived = true;

  final AssessmentData data;
  final AssessmentResult result;

  /// When the assessment was taken. Null means "just now".
  final DateTime? takenAt;

  final bool isArchived;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // A fresh result is filed the moment it is shown. Waiting for the user to
    // press something would lose the record for anyone who simply closes the
    // app after reading it — which is most people, most of the time.
    if (!widget.isArchived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HealthStore.instance.addRecord(
          AssessmentRecord.from(data: widget.data, result: widget.result),
        );
      });
    }
  }

  RiskLevel get _risk => RiskLevel.fromString(widget.result.riskLevel);

  /// Whether to offer the hospital finder.
  ///
  /// Driven by the parsed risk level rather than an exact string match on
  /// `'High'`, which silently failed for every other casing the backend sent.
  bool get _showHospitals =>
      _risk == RiskLevel.high || _risk == RiskLevel.emergency;

  IconData get _actionIcon => switch (_risk) {
    RiskLevel.high || RiskLevel.emergency => Icons.local_hospital_outlined,
    RiskLevel.medium => Icons.medical_services_outlined,
    RiskLevel.low => Icons.home_outlined,
  };

  void _onFindHospitals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HospitalFinderScreen(specialistName: widget.result.specialist.name),
      ),
    );
  }

  Future<void> _onShare() async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _reportText(),
          subject: 'Health-Bot Assessment Report',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet.')),
      );
    }
  }

  String _reportText() {
    final r = widget.result;
    final d = widget.data;
    final profile = HealthStore.instance.profile;

    final symptoms = d.symptoms.isNotEmpty ? d.symptoms : 'Not specified';
    final alts = r.alternateMatches.isNotEmpty
        ? r.alternateMatches.map((a) => '- $a').join('\n')
        : '- None';

    // The profile's medical history travels with the report: it is the part a
    // clinician most needs and the part the user is least likely to recite
    // accurately while unwell.
    final background = profile.contextLines.isEmpty
        ? ''
        : '\nBackground:\n${profile.contextLines.map((l) => '- $l').join('\n')}\n';

    return '''
Health-Bot Assessment Report

Date: ${Moment.date(widget.takenAt ?? DateTime.now())}

Symptoms: $symptoms
Age: ${d.age}
Duration: ${d.duration.label}
Severity: ${d.severity}/10
$background
Risk Level: ${r.riskLevel.toUpperCase()}
Recommended Action: ${r.recommendedAction}
Recommended Specialist: ${r.specialist.name}

Possible Conditions:
- ${r.conditionName} — ${r.confidenceLabel} (${r.matchPercentage.toInt()}% symptom match)
$alts

${_carePlanReport(r)}

Disclaimer: This is not a medical diagnosis. If in doubt, consult a healthcare professional.
''';
  }

  /// The care plan as plain text for the shared report. Falls back to the flat
  /// advice string when talking to a backend that predates care plans.
  String _carePlanReport(AssessmentResult r) {
    final plan = r.carePlan;
    if (plan.isEmpty) {
      final flat = r.advice.replaceAll('• ', '- ').replaceAll('* ', '- ');
      return 'Advice:\n$flat';
    }

    final buffer = StringBuffer('What you can do:');
    if (plan.goal.isNotEmpty) {
      buffer.write('\n${plan.goal}');
    }

    void section(String title, List<String> items) {
      if (items.isEmpty) return;
      buffer.write('\n\n$title:\n');
      buffer.write(items.map((i) => '- $i').join('\n'));
    }

    section('Do', plan.doThis);
    section('Avoid', plan.avoid);
    section('See a doctor if', plan.redFlags);
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AppTopBar(
              title: widget.isArchived ? 'Saved assessment' : 'Your result',
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: [
                AppIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share report',
                  onTap: _onShare,
                ),
              ],
            ),
          ),
          if (!widget.isArchived)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space20,
                AppTheme.gutter,
                AppTheme.space4,
              ),
              child: const StageTracker(currentStage: TriageStage.results),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space24,
                AppTheme.gutter,
                AppTheme.space40,
              ),
              children: [
                _VerdictCard(
                  result: r,
                  risk: _risk,
                  actionIcon: _actionIcon,
                  takenAt: widget.takenAt,
                ),

                const SizedBox(height: AppTheme.space16),
                if (!r.isInconclusive)
                  _ConditionCard(result: r)
                else
                  const _InconclusiveCard(),

                if (r.changesAnswer != null) ...[
                  const SizedBox(height: AppTheme.space16),
                  _ChangesAnswerCard(changes: r.changesAnswer!),
                ],

                const SizedBox(height: AppTheme.space16),
                _SpecialistCard(info: r.specialist),

                if (!r.carePlan.isEmpty) ...[
                  const SizedBox(height: AppTheme.space16),
                  _CarePlanCard(plan: r.carePlan),
                ] else if (r.advice.trim().isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space16),
                  _AdviceCard(advice: r.advice),
                ],

                if (r.alternateMatches.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space16),
                  _AlternativesCard(items: r.alternateMatches),
                ],

                const SizedBox(height: AppTheme.space16),
                _WhatYouToldUs(
                  data: widget.data,
                  ruledOut: r.ruledOutSymptoms,
                  riskFactors: r.riskFactors,
                ),

                const SizedBox(height: AppTheme.space24),
                if (_showHospitals) ...[
                  AppButton(
                    label: 'Find nearby hospitals',
                    icon: Icons.local_hospital_outlined,
                    variant: AppButtonVariant.danger,
                    haptic: PressHaptic.medium,
                    onPressed: _onFindHospitals,
                  ),
                  const SizedBox(height: AppTheme.space8),
                ],
                AppButton(
                  label: 'Share this report',
                  icon: Icons.ios_share_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: _onShare,
                ),

                const SizedBox(height: AppTheme.space24),
                const _Disclaimer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

/// The headline: risk level, and what to do about it.
/// What to do, how soon, and how risky this looks.
///
/// The disposition is the headline. The app used to lead with the condition
/// name and tuck the advice underneath it, which put the least reliable part
/// of the assessment in the largest type. Someone worried enough to open a
/// symptom checker wants to know whether to go to a doctor today — a guess at
/// which of 41 conditions they have is the supporting detail, not the answer.
class _VerdictCard extends StatelessWidget {
  const _VerdictCard({
    required this.result,
    required this.risk,
    required this.actionIcon,
    required this.takenAt,
  });

  final AssessmentResult result;
  final RiskLevel risk;
  final IconData actionIcon;
  final DateTime? takenAt;

  @override
  Widget build(BuildContext context) {
    final detail = result.dispositionDetail.trim().isNotEmpty
        ? result.dispositionDetail
        : result.recommendedAction;

    return AppCard(
      accent: risk.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (takenAt != null) ...[
            Text(
              'Recorded ${Moment.relative(takenAt!).toLowerCase()}',
              style: AppText.bodySm,
            ),
            const SizedBox(height: AppTheme.space16),
          ],

          // Read together by a screen reader: the label alone ("Urgent care
          // today") is meaningless without the timeframe beside it, and two
          // separate announcements split the one fact that matters most.
          Semantics(
            header: true,
            label:
                'Suggested next step: '
                '${result.dispositionLabel}, ${result.dispositionTimeframe}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(actionIcon, size: 22, color: risk.color),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Text(result.dispositionLabel, style: AppText.h1),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: StatusPill(
                    result.dispositionTimeframe,
                    color: risk.color,
                  ),
                ),
              ],
            ),
          ),

          if (detail.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(detail, style: AppText.body),
            ),
          ],

          const SizedBox(height: AppTheme.space20),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppTheme.space20),
          RiskBar(riskLevel: risk),
        ],
      ),
    );
  }
}

/// The single fact that would overturn this assessment.
///
/// Cheap honesty, and the most useful kind. A result reached from a handful
/// of yes/no questions over a 41-condition knowledge base is going to be
/// wrong sometimes; naming the symptom the answer hinges on lets a reader who
/// does have it go back and correct the record, and gives a reader who does
/// not a concrete reason to trust the rest.
class _ChangesAnswerCard extends StatelessWidget {
  const _ChangesAnswerCard({required this.changes});

  final ChangesAnswer changes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.pulse,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.alt_route_rounded, size: 19, color: AppColors.pulse),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What would change this', style: AppText.bodySm),
                const SizedBox(height: 3),
                Text(
                  'If you also had ${changes.symptom.toLowerCase()}, this '
                  'would point to ${changes.condition} instead.',
                  style: AppText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The condition the backend leaned toward, and why.
class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.result});

  final AssessmentResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Closest match', style: AppText.bodySm),
          const SizedBox(height: AppTheme.space4),
          Text(result.conditionName, style: AppText.h1),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              // The band leads and the percentage supports it: the figure comes
              // from a 41-condition teaching dataset, and showing it alone
              // implies a precision the model does not have.
              StatusPill(result.confidenceLabel, color: AppColors.pulse),
              const SizedBox(width: AppTheme.space8),
              Text(
                '${result.matchPercentage.toInt()}% symptom overlap',
                style: AppText.caption,
              ),
            ],
          ),
          if (result.matchedSymptoms.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: AppTheme.space16),
            Text('What pointed here', style: AppText.label),
            const SizedBox(height: AppTheme.space12),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                for (final s in result.matchedSymptoms)
                  StatusPill(s, color: AppColors.signal, filled: false),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InconclusiveCard extends StatelessWidget {
  const _InconclusiveCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('No clear match', style: AppText.bodySm),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Your symptoms did not point to one condition',
            style: AppText.h2,
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            'That is a normal outcome, not a failure. The risk level and the '
            'advice below still apply, and a clinician can narrow it down '
            'with the things an app cannot check.',
            style: AppText.bodySm,
          ),
        ],
      ),
    );
  }
}

class _SpecialistCard extends StatelessWidget {
  const _SpecialistCard({required this.info});

  final SpecialistInfo info;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.wash(AppColors.pulse, 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.pulse.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              size: 17,
              color: AppColors.pulse,
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who to see', style: AppText.bodySm),
                const SizedBox(height: 3),
                Text(info.name, style: AppText.h2),
                if (info.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space8),
                  Text(info.description, style: AppText.bodySm),
                ],
                if (info.department.trim().isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space12),
                  StatusPill(
                    info.department,
                    color: AppColors.pulse,
                    filled: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The non-medication next steps, in three groups.
///
/// Splitting them matters: "apply a cold cloth" and "call an ambulance if your
/// speech slurs" are not the same kind of instruction, and a single flat
/// bulleted list gave them the same weight. The red-flag group is deliberately
/// last and deliberately loud -- it is the one a reader must not skim past.
class _CarePlanCard extends StatelessWidget {
  const _CarePlanCard({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What you can do', style: AppText.label),
          if (plan.goal.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text(plan.goal, style: AppText.bodyMuted.copyWith(height: 1.5)),
          ],
          if (plan.doThis.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space20),
            _CarePlanGroup(
              title: 'Do',
              icon: Icons.check_rounded,
              tint: AppColors.signal,
              items: plan.doThis,
            ),
          ],
          if (plan.avoid.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space20),
            _CarePlanGroup(
              title: 'Avoid',
              icon: Icons.not_interested_rounded,
              tint: AppColors.riskModerate,
              items: plan.avoid,
            ),
          ],
          if (plan.redFlags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space20),
            Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: AppColors.wash(AppColors.riskHigh, 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppColors.wash(AppColors.riskHigh, 0.22),
                ),
              ),
              child: _CarePlanGroup(
                title: 'See a doctor if',
                icon: Icons.warning_amber_rounded,
                tint: AppColors.riskHigh,
                items: plan.redFlags,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One labelled group of steps. The icon repeats beside every line rather than
/// sitting once in the header, so a line still reads correctly on its own when
/// someone scrolls into the middle of a long group.
class _CarePlanGroup extends StatelessWidget {
  const _CarePlanGroup({
    required this.title,
    required this.icon,
    required this.tint,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          style: AppText.label.copyWith(color: tint, letterSpacing: 0.8),
        ),
        const SizedBox(height: AppTheme.space12),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTheme.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: Icon(icon, size: 16, color: tint),
              ),
              Expanded(
                child: Text(
                  items[i],
                  style: AppText.body.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final String advice;

  /// The backend sends advice as a bulleted blob with inconsistent markers.
  /// Splitting it into real list items is what lets each point get its own
  /// line and marker instead of running together in one paragraph.
  List<String> get _points {
    final normalised = advice.replaceAll('* ', '• ').replaceAll('- ', '• ');
    return normalised
        .split(RegExp(r'[•\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Advice', style: AppText.label),
          const SizedBox(height: AppTheme.space16),
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTheme.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 9, right: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.signal,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    points[i],
                    style: AppText.body.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Conditions considered and set aside. Collapsed, because they are context
/// for a curious reader rather than part of the answer.
class _AlternativesCard extends StatefulWidget {
  const _AlternativesCard({required this.items});

  final List<String> items;

  @override
  State<_AlternativesCard> createState() => _AlternativesCardState();
}

class _AlternativesCardState extends State<_AlternativesCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Also considered (${widget.items.length})',
                  style: AppText.label,
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: AppTheme.quick,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: AppTheme.quick,
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in widget.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 8, right: 12),
                            decoration: const BoxDecoration(
                              color: AppColors.textFaint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(child: Text(item, style: AppText.bodySm)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The inputs, played back as a measured record — what the result was actually
/// computed from.
class _WhatYouToldUs extends StatelessWidget {
  const _WhatYouToldUs({
    required this.data,
    required this.ruledOut,
    required this.riskFactors,
  });

  final AssessmentData data;
  final List<String> ruledOut;
  final List<String> riskFactors;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What you reported', style: AppText.label),
          const SizedBox(height: AppTheme.space12),
          DetailRow(
            label: 'Symptoms',
            value: data.symptoms.isNotEmpty ? data.symptoms : 'Not specified',
          ),
          DetailRow(label: 'Age', value: '${data.age}'),
          DetailRow(label: 'Duration', value: data.duration.label),
          DetailRow(label: 'Severity', value: '${data.severity}/10'),
          if (riskFactors.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: AppTheme.space16),
            Text('Risk factors', style: AppText.label),
            const SizedBox(height: AppTheme.space12),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                for (final f in riskFactors)
                  StatusPill(f, color: AppColors.riskModerate, filled: false),
              ],
            ),
          ],
          if (ruledOut.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: AppTheme.space16),
            // Ruled-out symptoms shape the result too, so showing them
            // explains why one condition was preferred over another.
            Text('You ruled out', style: AppText.label),
            const SizedBox(height: AppTheme.space12),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                for (final s in ruledOut)
                  StatusPill(s, color: AppColors.textFaint, filled: false),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: AppColors.textFaint,
        ),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: Text(
            'This is not a medical diagnosis. Health-Bot narrows down '
            'possibilities from what you described — a qualified clinician '
            'decides what it is.',
            style: AppText.caption,
          ),
        ),
      ],
    );
  }
}
