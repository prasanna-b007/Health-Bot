import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'dashed_divider.dart';

class AssessmentTagCard extends StatelessWidget {
  final String statusWord;
  final List<Widget> children;

  const AssessmentTagCard({
    super.key,
    required this.statusWord,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('assessment tag', style: AppText.dataLabel),
                Text(statusWord, style: AppText.dataLabel),
              ],
            ),
          ),
          const DashedDivider(),
          ...children.asMap().entries.expand((entry) {
            final isLast = entry.key == children.length - 1;
            return [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: entry.value,
              ),
              if (!isLast) const DashedDivider(),
            ];
          }),
        ],
      ),
    );
  }
}
