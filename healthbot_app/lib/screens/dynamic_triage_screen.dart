import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'emergency_screen.dart';
import 'results_screen.dart';

class DynamicTriageScreen extends StatefulWidget {
  final AssessmentData data;
  final TriageQuestion currentQuestion;
  final int questionNumber;

  const DynamicTriageScreen({
    super.key,
    required this.data,
    required this.currentQuestion,
    required this.questionNumber,
  });

  @override
  State<DynamicTriageScreen> createState() => _DynamicTriageScreenState();
}

class _DynamicTriageScreenState extends State<DynamicTriageScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;

  void _onAnswer(bool answer) async {
    setState(() => _isLoading = true);
    final response = await _apiService.answerQuestion(widget.currentQuestion.id, answer);
    
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
            questionNumber: widget.questionNumber + 1,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('question ${widget.questionNumber} of ~4', style: AppText.dataLabel, textAlign: TextAlign.center),
              const SizedBox(height: 48),
              Text(
                widget.currentQuestion.text,
                style: AppText.heading.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.ink))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('Yes', style: AppText.body),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('No', style: AppText.body),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
