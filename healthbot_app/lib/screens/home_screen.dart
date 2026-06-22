import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'assessment_form_screen.dart';
import 'emergency_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _onEmergency(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const EmergencyScreen(
          reason: 'User requested emergency help',
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _onCheckSymptoms(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AssessmentFormScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Health-Bot', style: AppText.heading.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                "Tell us what's wrong. We'll tell you what to do next.",
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => _onCheckSymptoms(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Check symptoms', style: AppText.body.copyWith(color: AppColors.surface)),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _onEmergency(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.riskHigh,
                  side: const BorderSide(color: AppColors.riskHigh, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Emergency help', style: AppText.body.copyWith(color: AppColors.riskHigh)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
