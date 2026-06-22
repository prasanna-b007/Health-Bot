import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/assessment_tag_card.dart';
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

  void _onSubmit() async {
    final symptoms = _symptomController.text.trim();
    if (symptoms.isEmpty) return;

    setState(() => _isLoading = true);
    widget.data.symptoms = symptoms;
    
    final response = await _apiService.sendAssessmentStart(widget.data);
    
    if (!mounted) return;
    setState(() => _isLoading = false);

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
    } else if (response.nextQuestion != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => DynamicTriageScreen(
            data: widget.data,
            currentQuestion: response.nextQuestion!,
            questionNumber: 1,
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
    }
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
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: AssessmentTagCard(
            statusWord: 'step 2',
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Primary Symptoms', style: AppText.heading),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _symptomController,
                    maxLines: 4,
                    style: AppText.body,
                    decoration: InputDecoration(
                      hintText: 'e.g. fever and headache',
                      hintStyle: AppText.bodyMuted,
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.ink),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be as specific as possible. We will use this to guide your triage.',
                    style: AppText.bodyMuted,
                  ),
                ],
              ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
                  : ElevatedButton(
                      onPressed: _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Submit', style: AppText.body.copyWith(color: AppColors.surface)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
