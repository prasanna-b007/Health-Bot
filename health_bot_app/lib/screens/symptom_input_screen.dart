import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import 'dynamic_triage_screen.dart';
import 'emergency_screen.dart';
import 'results_screen.dart';

class SymptomInputScreen extends StatefulWidget {
  final AssessmentData data;

  const SymptomInputScreen({super.key, required this.data});

  @override
  State<SymptomInputScreen> createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  final _symptomController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  final List<String> _commonSymptoms = [
    'Fever', 'Cough', 'Fatigue', 'Chills', 'Headache', 'Nausea'
  ];

  void _addSymptom(String symptom) {
    final current = _symptomController.text;
    if (current.isEmpty) {
      _symptomController.text = symptom.toLowerCase();
    } else {
      _symptomController.text = '$current and ${symptom.toLowerCase()}';
    }
  }

  void _onSubmit() async {
    final symptoms = _symptomController.text.trim();
    if (symptoms.isEmpty) return;

    setState(() => _isLoading = true);
    widget.data.symptoms = symptoms;

    final response = await _apiService.sendSymptoms(widget.data);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.hasError) {
      _showError(response.errorMessage!);
      return;
    }

    if (response.isEmergency) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => EmergencyScreen(
            reason: response.emergencyReason ?? 'Emergency symptoms detected.',
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (response.result != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ResultsScreen(
            data: widget.data,
            result: response.result!,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (response.nextQuestion != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => DynamicTriageScreen(
            data: widget.data,
            apiService: _apiService,
            currentQuestion: response.nextQuestion!,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.riskHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text('Describe Symptoms', style: AppText.h3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _symptomController,
                maxLines: 4,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: 'e.g. fever and headache',
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
                  contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              
              Text('Common Symptoms', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing16),
              
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: _commonSymptoms.map((s) => ActionChip(
                  label: Text(s, style: AppText.body.copyWith(fontSize: 14)),
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: () => _addSymptom(s),
                )).toList(),
              ),
              
              const Spacer(),
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
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ElevatedButton(
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.card,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                ),
                child: Text('Analyze', style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold)),
              ),
        ),
      ),
    );
  }
}
