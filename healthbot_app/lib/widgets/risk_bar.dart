import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

enum RiskLevel { low, medium, high, emergency }

class RiskBar extends StatelessWidget {
  final RiskLevel riskLevel;

  const RiskBar({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    double widthFactor = 0.0;
    Color barColor = AppColors.background;
    String riskWord = '';
    Color wordColor = AppColors.surface;
    Color badgeBg = AppColors.ink;

    switch (riskLevel) {
      case RiskLevel.low:
        widthFactor = 0.25;
        barColor = AppColors.riskLow;
        riskWord = 'low';
        badgeBg = AppColors.riskLow;
        break;
      case RiskLevel.medium:
        widthFactor = 0.50;
        barColor = AppColors.riskMedium;
        riskWord = 'medium';
        badgeBg = AppColors.riskMedium;
        break;
      case RiskLevel.high:
        widthFactor = 0.85;
        barColor = AppColors.riskHigh;
        riskWord = 'high';
        badgeBg = AppColors.riskHigh;
        break;
      case RiskLevel.emergency:
        widthFactor = 1.0;
        barColor = AppColors.riskHigh;
        riskWord = 'emergency';
        badgeBg = AppColors.riskHigh;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('risk', style: AppText.dataLabel),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                riskWord,
                style: AppText.dataLabel.copyWith(color: wordColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (riskLevel == RiskLevel.emergency)
              Container(
                height: 10,
                width: double.infinity, // 100% width, no animation
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    height: 10,
                    width: constraints.maxWidth * widthFactor,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
