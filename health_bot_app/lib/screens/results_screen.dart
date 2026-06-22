import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import 'emergency_screen.dart';

class ResultsScreen extends StatelessWidget {
  final AssessmentData data;
  final AssessmentResult result;

  const ResultsScreen({
    super.key,
    required this.data,
    required this.result,
  });

  Color _getRiskColor() {
    switch (result.riskLevel.toLowerCase()) {
      case 'low': return AppColors.riskLow;
      case 'medium': return AppColors.riskModerate;
      case 'moderate': return AppColors.riskModerate;
      case 'high': return AppColors.riskHigh;
      case 'emergency': return AppColors.riskHigh;
      default: return AppColors.riskModerate;
    }
  }

  String _getRiskEmoji() {
    switch (result.riskLevel.toLowerCase()) {
      case 'low': return '🟢';
      case 'medium': return '🟡';
      case 'moderate': return '🟡';
      case 'high': return '🔴';
      case 'emergency': return '🔴';
      default: return '🟡';
    }
  }

  void _onFindHospitals(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const EmergencyScreen(
          reason: 'High risk condition. Hospital care recommended.',
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text('Assessment Complete', style: AppText.h3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_getRiskEmoji()} ${result.riskLevel.toUpperCase()} RISK',
                style: AppText.h2.copyWith(color: _getRiskColor()),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              
              Text('Most Likely Condition', style: AppText.bodyMuted),
              const SizedBox(height: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  boxShadow: AppTheme.premiumShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.conditionName, style: AppText.h1),
                    const SizedBox(height: AppTheme.spacing4),
                    Text('${result.matchPercentage}% Confidence', style: AppText.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              
              if (result.alternateMatches.isNotEmpty) ...[
                Text('Alternatives', style: AppText.h3),
                const SizedBox(height: AppTheme.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.alternateMatches.map((alt) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                      child: Text(alt, style: AppText.body),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],
              
              if (result.riskFactors.isNotEmpty) ...[
                Text('Risk Factors Considered', style: AppText.h3),
                const SizedBox(height: AppTheme.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.riskFactors.map((factor) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✓ ', style: TextStyle(color: AppColors.primary)),
                          Expanded(child: Text(factor, style: AppText.body)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],
              
              Text('Advice', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  result.advice.replaceAll('* ', '• '), 
                  style: AppText.body.copyWith(height: 1.5)
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: AppTheme.premiumShadow,
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => _onFindHospitals(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.card,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
            ),
            child: Text('Find Nearby Hospitals', style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
