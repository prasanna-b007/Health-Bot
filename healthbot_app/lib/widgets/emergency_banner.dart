import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class EmergencyBanner extends StatelessWidget {
  final String reason;

  const EmergencyBanner({
    super.key,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: AppColors.riskHigh, size: 24),
              const SizedBox(width: 8),
              Text('Emergency detected', style: AppText.heading.copyWith(color: AppColors.riskHigh)),
            ],
          ),
          const SizedBox(height: 4),
          Text(reason, style: AppText.bodyMuted),
        ],
      ),
    );
  }
}
