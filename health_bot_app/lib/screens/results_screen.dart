import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/assessment_data.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/assessment_tag_card.dart';
import '../widgets/dashed_divider.dart';
import '../widgets/data_row.dart';
import '../widgets/risk_bar.dart';

import '../services/api_service.dart';
import 'hospital_finder_screen.dart';
import '../widgets/stage_tracker.dart';

class ResultsScreen extends StatelessWidget {
  final AssessmentData data;
  final AssessmentResult result;
  final ApiService apiService;

  const ResultsScreen({
    super.key,
    required this.data,
    required this.result,
    required this.apiService,
  });

  RiskLevel _getRiskLevel() {
    switch (result.riskLevel.toLowerCase()) {
      case 'low': return RiskLevel.low;
      case 'moderate': return RiskLevel.medium;
      case 'medium': return RiskLevel.medium;
      case 'high': return RiskLevel.high;
      case 'emergency': return RiskLevel.emergency;
      default: return RiskLevel.medium;
    }
  }

  IconData _getActionIcon() {
    final risk = result.riskLevel.toLowerCase();
    if (risk == 'high' || risk == 'emergency') {
      return Icons.local_hospital_outlined;
    } else if (risk == 'moderate') {
      return Icons.medical_services_outlined;
    } else {
      return Icons.home_outlined;
    }
  }

  bool get _showHospitalButton {
    return result.riskLevel == 'High';
  }

  void _onFindHospitals(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => HospitalFinderScreen(
          apiService: apiService,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _onShareReport(BuildContext context) async {
    // Phase 4: Share report functionality
    final text = _buildReportText();
    // Use share_plus when available, for now copy to clipboard
    try {
      // Dynamic import to avoid hard dependency before share_plus is added
      await _shareText(text, context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report copied to clipboard'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareText(String text, BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Health-Bot Assessment Report',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      )
    );
  }

  String _buildReportText() {
    final symptoms = data.symptoms.isNotEmpty ? data.symptoms : 'Not specified';
    final alts = result.alternateMatches.isNotEmpty
        ? result.alternateMatches.map((a) => '- $a').join('\n')
        : '- None';
    final advice = result.advice.replaceAll('• ', '- ');

    return '''
Health-Bot Assessment Report

Date: ${DateTime.now().toString().split(' ')[0]}

Symptoms: $symptoms
Risk Level: ${result.riskLevel.toUpperCase()}
Recommended Action: ${result.recommendedAction}

Possible Conditions:
- ${result.conditionName} (${result.matchPercentage.toInt()}%)
$alts

Advice:
$advice

Disclaimer: This is not a medical diagnosis. If in doubt, consult a healthcare professional.
''';
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
              const StageTracker(currentStage: TriageStage.results),
              const SizedBox(height: AppTheme.spacing24),
              AssessmentTagCard(
                statusWord: 'ASSESSMENT',
                children: [
                  // ── Header row ──
                  Text(
                    'ASSESSMENT TAG',
                    style: AppText.dataLabel.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),

                  // ── Data rows ──
                  TagDataRow(
                    label: 'SYMPTOMS',
                    value: data.symptoms.isNotEmpty ? data.symptoms : 'Not specified',
                  ),
                  TagDataRow(label: 'AGE', value: '${data.age}'),
                  TagDataRow(label: 'DURATION', value: data.duration),
                  TagDataRow(label: 'SEVERITY', value: '${data.severity}/10'),

                  const SizedBox(height: AppTheme.spacing16),
                  const DashedDivider(),
                  const SizedBox(height: AppTheme.spacing16),

                  // ── Recommended Action ──
                  if (result.recommendedAction.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(_getActionIcon(), size: 20, color: AppColors.ink),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: Text(
                            result.recommendedAction,
                            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                  ],

                  // ── Risk Bar ──
                  RiskBar(riskLevel: _getRiskLevel()),

                  const DashedDivider(),
                  const SizedBox(height: AppTheme.spacing16),

                  // ── Top Condition Card ──
                  if (result.conditionName.isNotEmpty && result.conditionName != 'Unknown') ...[
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.conditionName, style: AppText.heading),
                          const SizedBox(height: AppTheme.spacing8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${result.matchPercentage.toInt()}%',
                                  style: AppText.dataValue.copyWith(color: AppColors.primary),
                                ),
                                TextSpan(
                                  text: ' confidence',
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (result.matchedSymptoms.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacing8),
                            Wrap(
                              spacing: AppTheme.spacing8,
                              runSpacing: AppTheme.spacing8,
                              children: result.matchedSymptoms.map((s) => Container(
                                padding: const EdgeInsets.all(AppTheme.spacing8), // Nearest multiple of 8
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  s,
                                  style: AppText.caption.copyWith(fontSize: 12),
                                ),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                  ],

                  // ── Less Likely Conditions (collapsed by default) ──
                  if (result.alternateMatches.isNotEmpty) ...[
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background, // Token swap (surface -> background)
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: 0),
                          childrenPadding: const EdgeInsets.only(bottom: AppTheme.spacing8, left: AppTheme.spacing16, right: AppTheme.spacing16),
                          title: Text(
                            'Less Likely Conditions',
                            style: AppText.bodyMuted.copyWith(fontSize: 14),
                          ),
                          children: result.alternateMatches.map((alt) => Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0), // 4.0 aligns icon vertically with text baseline
                                  child: Icon(Icons.remove, size: 14, color: AppColors.subtext),
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Expanded(
                                  child: Text(alt, style: AppText.body.copyWith(fontSize: 14)),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                  ],

                  // ── Advice list ──
                  Text('Advice', style: AppText.h3.copyWith(fontSize: 16)),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    result.advice.replaceAll('* ', '• '),
                    style: AppText.body.copyWith(height: 1.6),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // ── Action buttons ──
                  if (_showHospitalButton) ...[
                    Builder(
                      builder: (ctx) => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _onFindHospitals(ctx),
                          icon: const Icon(Icons.local_hospital_outlined, size: 18),
                          label: Text(
                            'Find Nearby Hospitals',
                            style: AppText.body.copyWith(
                              color: AppColors.card,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.card,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                  ],

                  Builder(
                    builder: (ctx) => SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _onShareReport(ctx),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: Text(
                          'Share Report',
                          style: AppText.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing16),

              // ── Disclaimer ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
                child: Text(
                  'This is not a medical diagnosis. Please consult a qualified healthcare professional.',
                  style: AppText.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
      ),
    );
  }
}
