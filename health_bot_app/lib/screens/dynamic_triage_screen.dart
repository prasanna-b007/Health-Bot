import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import 'emergency_screen.dart';
import 'results_screen.dart';

class DynamicTriageScreen extends StatefulWidget {
  final AssessmentData data;
  final ApiService apiService;
  final TriageQuestion currentQuestion;

  const DynamicTriageScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.currentQuestion,
  });

  @override
  State<DynamicTriageScreen> createState() => _DynamicTriageScreenState();
}

class _DynamicTriageScreenState extends State<DynamicTriageScreen> {
  bool _isLoading = false;
  late TriageQuestion _question;
  int _questionIndex = 1;

  @override
  void initState() {
    super.initState();
    _question = widget.currentQuestion;
    _questionIndex = widget.currentQuestion.questionNumber;
  }

  void _onAnswer(bool answer) async {
    setState(() => _isLoading = true);

    final response = await widget.apiService.answerQuestion(answer);

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
      return;
    }

    if (response.result != null) {
      Navigator.pushReplacement(
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
      return;
    }

    if (response.nextQuestion != null) {
      setState(() {
        _question = response.nextQuestion!;
        _questionIndex = response.nextQuestion!.questionNumber;
      });
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
  Widget build(BuildContext context) {
    final progress = (_questionIndex / 5.0).clamp(0.0, 1.0);

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
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Progress', style: AppText.h3),
              const SizedBox(height: AppTheme.spacing8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text('Question $_questionIndex of 5', style: AppText.dataLabel),
              
              const SizedBox(height: AppTheme.spacing48),
              
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  _question.text,
                  key: ValueKey<int>(_questionIndex),
                  style: AppText.h2,
                  textAlign: TextAlign.center,
                ),
              ),
              
              const Spacer(),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        ),
                        child: Text('YES', style: AppText.body.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.subtext,
                          side: const BorderSide(color: AppColors.border, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        ),
                        child: Text('NO', style: AppText.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.subtext)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
      ),
    );
  }
}
