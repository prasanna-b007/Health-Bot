import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.premiumShadow,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
