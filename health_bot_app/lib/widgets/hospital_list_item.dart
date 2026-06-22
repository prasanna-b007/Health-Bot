import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';

class HospitalListItem extends StatelessWidget {
  final String name;
  final String distance;
  final VoidCallback onCallPressed;

  const HospitalListItem({
    super.key,
    required this.name,
    required this.distance,
    required this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏥 ', style: TextStyle(fontSize: 20)),
            Expanded(child: Text(name, style: AppText.h3)),
          ],
        ),
        const SizedBox(height: 4),
        Text(distance, style: AppText.bodyMuted),
        const SizedBox(height: 4),
        Text('★★★★★', style: AppText.caption.copyWith(color: AppColors.riskModerate)), // Static for UI mock
        const SizedBox(height: AppTheme.spacing16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCallPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Call', style: AppText.body.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: OutlinedButton(
                onPressed: () {}, // Real app opens map
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Directions', style: AppText.body.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
