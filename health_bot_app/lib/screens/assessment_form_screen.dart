import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import 'symptom_input_screen.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  int _age = 22;
  String _duration = '2-3 days';
  int _severity = 5;

  final List<String> _durations = ['1 day', '2-3 days', '4-7 days', '> 1 week'];

  void _onContinue() {
    final data = AssessmentData(
      age: _age,
      duration: _duration,
      severity: _severity,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SymptomInputScreen(data: data)),
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
        title: Text('Health Assessment', style: AppText.h3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Age', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing16),
              TextField(
                keyboardType: TextInputType.number,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: 'Enter your age',
                  hintStyle: AppText.bodyMuted,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: AppTheme.spacing16),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null) {
                    setState(() => _age = parsed);
                  }
                },
              ),
              const SizedBox(height: AppTheme.spacing32),
              
              Text('Duration', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing16),
              ..._durations.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: InkWell(
                  onTap: () => setState(() => _duration = d),
                  borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                      border: Border.all(color: _duration == d ? AppColors.secondary : AppColors.border, width: _duration == d ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(_duration == d ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _duration == d ? AppColors.secondary : AppColors.subtext),
                        const SizedBox(width: AppTheme.spacing16),
                        Text(d, style: AppText.body),
                      ],
                    ),
                  ),
                ),
              )),
              
              const SizedBox(height: AppTheme.spacing32),
              
              Text('Severity', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.secondary,
                        inactiveTrackColor: AppColors.border,
                        thumbColor: AppColors.secondary,
                        overlayColor: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _severity.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _severity.toString(),
                        onChanged: (val) => setState(() => _severity = val.toInt()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1', style: AppText.caption),
                          Text('10', style: AppText.caption),
                        ],
                      ),
                    ),
                  ],
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
            onPressed: _onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.card,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
            ),
            child: Text('Continue', style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
