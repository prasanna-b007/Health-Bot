import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

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
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: AppText.body),
                const SizedBox(height: 2),
                Text(distance, style: AppText.bodyMuted),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.inkMuted),
            onPressed: onCallPressed,
            splashRadius: 24,
          ),
        ],
      ),
    );
  }
}
