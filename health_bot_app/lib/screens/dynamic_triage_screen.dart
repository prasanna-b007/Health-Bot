import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import 'emergency_screen.dart';
import 'results_screen.dart';

import '../widgets/stage_tracker.dart';

/// Wizard-style smart medical interview screen.
///
/// One question per screen with crossfade transitions, Yes/No/Unsure buttons,
/// expandable "Why are we asking?" reason, and a Previous button for navigation.
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
  bool _reasonExpanded = false;

  /// Client-side history stack for the Previous button.
  /// Stores each question/answer pair so we can navigate back
  /// without re-querying the backend.
  final List<QuestionAnswer> _history = [];

  @override
  void initState() {
    super.initState();
    _question = widget.currentQuestion;
  }

  /// Strips all markdown bold markers (**) from text.
  String _cleanMarkdown(String text) {
    return text.replaceAll('**', '');
  }

  /// Attempts to extract a symptom keyword from the question text.
  /// Returns (prefix, keyword, suffix) where keyword is the emphasized part.
  /// Falls back to (fullText, '', '') if no keyword can be extracted.
  (String, String, String) _splitQuestionText(String rawText) {
    final text = _cleanMarkdown(rawText);

    // Pattern 1: "...do you have XYZ?" or "...do you experience XYZ?"
    final doYouPattern = RegExp(
      r'(.+?(?:do you (?:have|experience|notice|feel|see|get)\s+))(.+?)([?.]?)\s*$',
      caseSensitive: false,
    );
    final m1 = doYouPattern.firstMatch(text);
    if (m1 != null) {
      return (m1.group(1)!.trim(), m1.group(2)!.trim(), m1.group(3) ?? '');
    }

    // Pattern 2: "Have you experienced XYZ?"
    final haveYouPattern = RegExp(
      r'(.+?(?:(?:Have|Has|Are|Is|Do|Does|Did|Were|Was) you \w+\s+))(.+?)([?.]?)\s*$',
      caseSensitive: false,
    );
    final m2 = haveYouPattern.firstMatch(text);
    if (m2 != null) {
      return (m2.group(1)!.trim(), m2.group(2)!.trim(), m2.group(3) ?? '');
    }

    return (text, '', '');
  }

  void _onAnswer(AnswerType answer) async {
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
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            data: widget.data,
            result: response.result!,
            apiService: widget.apiService,
          ),
        ),
      );
      return;
    }

    if (response.nextQuestion != null) {
      // Push current question + answer into history before moving forward
      _history.add(QuestionAnswer(question: _question, answer: answer));
      setState(() {
        _question = response.nextQuestion!;
        _reasonExpanded = false;
      });
    }
  }

  void _onPrevious() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    setState(() {
      _question = previous.question;
      _reasonExpanded = false;
    });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text('Smart Medical Interview', style: AppText.h3),
        centerTitle: true,
        leading: _history.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: _onPrevious,
              )
            : IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StageTracker(currentStage: TriageStage.assessment),
              const SizedBox(height: AppTheme.spacing24),

              // ── Question text (with keyword emphasis) ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Column(
                  key: ValueKey<String>('q_${_question.questionNumber}_${_question.text.hashCode}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final (prefix, keyword, suffix) = _splitQuestionText(_question.text);
                        if (keyword.isEmpty) {
                          // No keyword extracted — show plain cleaned text
                          return Text(
                            prefix,
                            style: AppText.body.copyWith(fontSize: 18, height: 1.5, color: AppColors.subtext),
                            textAlign: TextAlign.left,
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prefix,
                              style: AppText.body.copyWith(fontSize: 18, height: 1.5, color: AppColors.subtext),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: AppTheme.spacing8),
                            Text(
                              '$keyword$suffix',
                              style: AppText.h1.copyWith(fontSize: 28, height: 1.3),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Question ${_question.questionNumber} of ~${_question.estimatedTotal}',
                      style: AppText.dataLabel,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing16),

              // ── "Why are we asking?" — prominent card toggle ──
              if (_question.reason.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _reasonExpanded = !_reasonExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _reasonExpanded
                          ? AppColors.secondary.withValues(alpha: 0.06)
                          : AppColors.card,
                      borderRadius: _reasonExpanded
                          ? const BorderRadius.vertical(top: Radius.circular(14))
                          : BorderRadius.circular(14),
                      border: Border.all(
                        color: _reasonExpanded
                            ? AppColors.secondary.withValues(alpha: 0.25)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: _reasonExpanded ? AppColors.secondary : AppColors.subtext,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Why are we asking?',
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _reasonExpanded ? AppColors.secondary : AppColors.subtext,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _reasonExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: _reasonExpanded ? AppColors.secondary : AppColors.subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                      border: Border(
                        left: BorderSide(color: AppColors.secondary.withValues(alpha: 0.25)),
                        right: BorderSide(color: AppColors.secondary.withValues(alpha: 0.25)),
                        bottom: BorderSide(color: AppColors.secondary.withValues(alpha: 0.25)),
                      ),
                    ),
                    child: Text(
                      _cleanMarkdown(_question.reason),
                      style: AppText.body.copyWith(fontSize: 14, height: 1.6, color: AppColors.text),
                    ),
                  ),
                  crossFadeState: _reasonExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],

              const SizedBox(height: AppTheme.spacing32),

              // ── Answer buttons ──
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Yes button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(AnswerType.yes),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        ),
                        child: Text(
                          'Yes',
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),

                    // No button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(AnswerType.no),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        ),
                        child: Text(
                          'No',
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),

                    // I'm Not Sure button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _onAnswer(AnswerType.unsure),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        ),
                        child: Text(
                          "I'm Not Sure",
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
