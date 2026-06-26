import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

enum RiskLevel { low, medium, high, emergency }

class RiskBar extends StatelessWidget {
  final RiskLevel riskLevel;

  const RiskBar({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    Color riskColor;
    double fillPercent;

    switch (riskLevel) {
      case RiskLevel.low:
        riskColor = AppColors.riskLow;
        fillPercent = 0.33;
        break;
      case RiskLevel.medium:
        riskColor = AppColors.riskModerate;
        fillPercent = 0.66;
        break;
      case RiskLevel.high:
      case RiskLevel.emergency:
        riskColor = AppColors.riskHigh;
        fillPercent = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RISK', style: AppText.dataLabel.copyWith(letterSpacing: 0.4)),
            Text(riskLevel.name.toUpperCase(), style: AppText.dataValue.copyWith(color: riskColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: constraints.maxWidth * fillPercent,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
