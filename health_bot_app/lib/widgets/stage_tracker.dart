import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

enum TriageStage {
  symptoms('Symptoms'),
  assessment('Interview'),
  results('Result');

  const TriageStage(this.label);
  final String label;
}

/// Where the user is in the triage flow.
///
/// "Step 2 of 3 · Interview", over three short bars. Said in words first,
/// because a person mid-triage wants to know how much is left, and a rail with
/// glowing nodes makes them work that out from a picture.
///
/// The interview is many questions inside one step, so its own progress fills
/// the current segment rather than getting a second bar underneath. Two
/// progress bars stacked on one screen is a question the user should not have
/// to answer ("which one is me?").
class StageTracker extends StatelessWidget {
  const StageTracker({
    super.key,
    required this.currentStage,
    this.stageProgress = 1.0,
    this.note,
  });

  final TriageStage currentStage;

  /// How far through the current stage, 0..1. Only the interview has any
  /// inside it, so everything else leaves this at 1.
  final double stageProgress;

  /// A line under the bar naming that progress in words.
  final String? note;

  @override
  Widget build(BuildContext context) {
    const stages = TriageStage.values;
    final index = currentStage.index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Step ${index + 1} of ${stages.length}',
              style: AppText.bodySm,
            ),
            Text(' · ', style: AppText.bodySm),
            Text(
              currentStage.label,
              style: AppText.bodySm.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: _Segment(
                  fill: i < index
                      ? 1.0
                      : i == index
                      ? stageProgress.clamp(0.0, 1.0)
                      : 0.0,
                ),
              ),
            ],
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: AppTheme.space8),
          Text(note!, style: AppText.bodySm),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(color: AppColors.surfaceHigh),
              AnimatedContainer(
                duration: AppTheme.medium,
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * fill,
                color: AppColors.signal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
