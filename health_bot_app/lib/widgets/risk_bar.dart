import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'ui.dart';

enum RiskLevel {
  low,
  medium,
  high,
  emergency;

  Color get color => switch (this) {
    RiskLevel.low => AppColors.riskLow,
    RiskLevel.medium => AppColors.riskModerate,
    RiskLevel.high => AppColors.riskHigh,
    RiskLevel.emergency => AppColors.ember,
  };

  String get label => switch (this) {
    RiskLevel.low => 'Low',
    RiskLevel.medium => 'Moderate',
    RiskLevel.high => 'High',
    RiskLevel.emergency => 'Emergency',
  };

  /// How many steps of the four-step scale are filled at this level.
  int get steps => switch (this) {
    RiskLevel.low => 1,
    RiskLevel.medium => 2,
    RiskLevel.high => 3,
    RiskLevel.emergency => 4,
  };

  static RiskLevel fromString(String value) => switch (value.toLowerCase()) {
    'low' => RiskLevel.low,
    'moderate' || 'medium' => RiskLevel.medium,
    'high' => RiskLevel.high,
    'emergency' => RiskLevel.emergency,
    _ => RiskLevel.medium,
  };
}

/// The risk level, as four steps.
///
/// Four, because that is exactly how many bands the backend has. The previous
/// meter drew twenty-two segments with a partially lit leading edge, which
/// invited people to read a precision off it that the underlying score — a
/// coarse band from a teaching dataset — does not have. Four filled steps say
/// "the third of four", which is all that is actually known.
class RiskBar extends StatelessWidget {
  const RiskBar({super.key, required this.riskLevel, this.showScale = true});

  final RiskLevel riskLevel;
  final bool showScale;

  @override
  Widget build(BuildContext context) {
    // The four steps are a picture of one value. Announced separately they are
    // four meaningless rectangles, so the whole meter collapses into a single
    // label and the decoration is excluded from the accessibility tree.
    return Semantics(
      label:
          'Risk level: ${riskLevel.label}, '
          '${riskLevel.steps} out of ${RiskLevel.values.length}',
      excludeSemantics: true,
      child: _buildMeter(context),
    );
  }

  Widget _buildMeter(BuildContext context) {
    final color = riskLevel.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Risk level', style: AppText.bodySm),
            const Spacer(),
            StatusPill(riskLevel.label, color: color),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            for (var i = 1; i <= RiskLevel.values.length; i++) ...[
              if (i > 1) const SizedBox(width: 5),
              Expanded(
                child: AnimatedContainer(
                  duration: AppTheme.medium,
                  curve: Curves.easeOut,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= riskLevel.steps ? color : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showScale) ...[
          const SizedBox(height: AppTheme.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: AppText.caption),
              Text('Emergency', style: AppText.caption),
            ],
          ),
        ],
      ],
    );
  }
}
