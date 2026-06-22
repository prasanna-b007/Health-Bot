import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/assessment_tag_card.dart';
import '../widgets/data_row.dart';
import '../widgets/risk_bar.dart';
import 'emergency_screen.dart';

class ResultsScreen extends StatelessWidget {
  final AssessmentData data;
  final AssessmentResult result;

  const ResultsScreen({
    super.key,
    required this.data,
    required this.result,
  });

  RiskLevel _getRiskLevel(String riskString) {
    switch (riskString.toLowerCase()) {
      case 'low': return RiskLevel.low;
      case 'medium': return RiskLevel.medium;
      case 'high': return RiskLevel.high;
      case 'emergency': return RiskLevel.emergency;
      default: return RiskLevel.medium;
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
    final riskEnum = _getRiskLevel(result.riskLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AssessmentTagCard(
                statusWord: 'complete',
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TagDataRow(label: 'symptom_text', value: data.symptoms.length > 20 ? '${data.symptoms.substring(0, 20)}...' : data.symptoms),
                      TagDataRow(label: 'age', value: data.age.toString()),
                      TagDataRow(label: 'duration', value: data.duration),
                      TagDataRow(label: 'severity', value: '${data.severity}/10'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.conditionName, style: AppText.heading.copyWith(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('${result.matchPercentage}% match', style: AppText.dataLabel),
                      if (result.alternateMatches.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Alt: ${result.alternateMatches.join(", ")}', style: AppText.bodyMuted),
                      ]
                    ],
                  ),
                  RiskBar(riskLevel: riskEnum),
                  Text(result.advice, style: AppText.body),
                  if (riskEnum == RiskLevel.high)
                    ElevatedButton(
                      onPressed: () => _onFindHospitals(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Find nearby hospitals', style: AppText.body.copyWith(color: AppColors.surface)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This estimates risk. It does not diagnose.',
                style: AppText.dataLabel,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
