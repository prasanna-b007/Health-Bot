import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import 'assessment_form_screen.dart';
import 'emergency_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spacing16),
              Text('Hi Prasanna 👋', style: AppText.bodyMuted),
              const SizedBox(height: AppTheme.spacing8),
              Text('How are you feeling today?', style: AppText.h1),
              const SizedBox(height: AppTheme.spacing32),
              
              _ActionCard(
                icon: Icons.medical_services_outlined,
                title: 'Check My Symptoms',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AssessmentFormScreen()),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              
              _ActionCard(
                icon: Icons.warning_amber_rounded,
                title: 'Emergency Help',
                isEmergency: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmergencyScreen(reason: 'User activated emergency mode.')),
                ),
              ),
              
              const Spacer(),
              Text('Quick Facts', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text('💧', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(child: Text('Stay hydrated today', style: AppText.body)),
                  ],
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isEmergency;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: isEmergency ? Border.all(color: AppColors.riskHigh.withValues(alpha: 0.3), width: 1) : null,
          boxShadow: isEmergency 
            ? [BoxShadow(color: AppColors.riskHigh.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))] 
            : AppTheme.premiumShadow,
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isEmergency ? AppColors.riskHigh : AppColors.primary),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(child: Text(title, style: AppText.h3.copyWith(color: isEmergency ? AppColors.riskHigh : AppColors.primary))),
            Icon(Icons.arrow_forward_ios, size: 16, color: isEmergency ? AppColors.riskHigh : AppColors.subtext),
          ],
        ),
      ),
    );
  }
}
