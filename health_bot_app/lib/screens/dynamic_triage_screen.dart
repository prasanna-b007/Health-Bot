import 'package:flutter/material.dart';

import '../models/assessment_data.dart';
import '../motion/pressable.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/ui.dart';
import '../widgets/stage_tracker.dart';
import 'crisis_screen.dart';
import 'hospital_finder_screen.dart';
import 'results_screen.dart';

/// The adaptive medical interview: one question at a time.
///
/// One question per screen is the whole design. The backend picks what to ask
/// next from what has been answered, so there is no form to scroll and no way
/// to skip ahead — and that constraint is what lets the question itself be set
/// large enough to read at arm's length while unwell.
class DynamicTriageScreen extends StatefulWidget {
  const DynamicTriageScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.currentQuestion,
  });

  final AssessmentData data;
  final ApiService apiService;
  final TriageQuestion currentQuestion;

  @override
  State<DynamicTriageScreen> createState() => _DynamicTriageScreenState();
}

class _DynamicTriageScreenState extends State<DynamicTriageScreen> {
  bool _isLoading = false;
  late TriageQuestion _question;
  bool _reasonExpanded = false;

  /// Client-side history stack for the Previous button, so stepping back does
  /// not have to re-query the backend.
  final List<QuestionAnswer> _history = [];

  @override
  void initState() {
    super.initState();
    _question = widget.currentQuestion;
  }

  String _cleanMarkdown(String text) => text.replaceAll('**', '');

  /// Splits a question into its lead-in and the symptom being asked about, so
  /// the symptom can be set large and the scaffolding small.
  ///
  /// Falls back to the whole sentence when no keyword can be found — an
  /// unusual phrasing must still render as a readable question.
  (String, String, String) _splitQuestionText(String rawText) {
    final text = _cleanMarkdown(rawText);

    final doYou = RegExp(
      r'(.+?(?:do you (?:have|experience|notice|feel|see|get)\s+))(.+?)([?.]?)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (doYou != null) {
      return (
        doYou.group(1)!.trim(),
        doYou.group(2)!.trim(),
        doYou.group(3) ?? '',
      );
    }

    final haveYou = RegExp(
      r'(.+?(?:(?:Have|Has|Are|Is|Do|Does|Did|Were|Was) you \w+\s+))(.+?)([?.]?)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (haveYou != null) {
      return (
        haveYou.group(1)!.trim(),
        haveYou.group(2)!.trim(),
        haveYou.group(3) ?? '',
      );
    }

    return (text, '', '');
  }

  Future<void> _onAnswer(AnswerType answer) async {
    setState(() => _isLoading = true);

    final response = await widget.apiService.answerQuestion(answer);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.hasError) {
      _showError(response.errorMessage!);
      return;
    }

    if (response.isEmergency) {
      // A crisis disclosure and a medical emergency both stop triage here,
      // but they part ways at the destination: a crisis line versus the
      // nearest emergency department.
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => response.isCrisis
              ? const CrisisScreen()
              : HospitalFinderScreen(
                  emergencyReason:
                      response.emergencyReason ??
                      'Emergency symptoms detected.',
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
          builder: (_) =>
              ResultsScreen(data: widget.data, result: response.result!),
        ),
      );
      return;
    }

    if (response.nextQuestion != null) {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final total = _question.estimatedTotal <= 0 ? 1 : _question.estimatedTotal;
    final progress = (_question.questionNumber / total).clamp(0.0, 1.0);

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AppTopBar(
              title: 'Interview',
              leading: AppIconButton(
                icon: _history.isNotEmpty
                    ? Icons.arrow_back_rounded
                    : Icons.close_rounded,
                tooltip: _history.isNotEmpty ? 'Previous question' : 'Exit',
                onTap: _history.isNotEmpty
                    ? _onPrevious
                    : () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              AppTheme.space20,
              AppTheme.gutter,
              AppTheme.space4,
            ),
            // The interview's own progress fills the middle segment, and the
            // count is spelled out underneath. "About", because the backend
            // may ask more or fewer than it estimated — a bare percentage
            // would read as a promise.
            child: StageTracker(
              currentStage: TriageStage.assessment,
              stageProgress: progress,
              note: 'Question ${_question.questionNumber} of about $total',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space24,
                AppTheme.gutter,
                AppTheme.space24,
              ),
              children: [
                AnimatedSwitcher(
                  duration: AppTheme.medium,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  // The new question rises as it fades in, echoing the
                  // direction of moving forward through the interview.
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _QuestionText(
                    key: ValueKey(
                      'q${_question.questionNumber}_${_question.text.hashCode}',
                    ),
                    parts: _splitQuestionText(_question.text),
                  ),
                ),

                if (_question.reason.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space24),
                  _WhyCard(
                    reason: _cleanMarkdown(_question.reason),
                    expanded: _reasonExpanded,
                    onToggle: () =>
                        setState(() => _reasonExpanded = !_reasonExpanded),
                  ),
                ],

                const SizedBox(height: AppTheme.space40),

                if (_isLoading)
                  const _Thinking()
                else
                  Column(
                    children: [
                      AppButton(
                        label: 'Yes',
                        icon: Icons.check_rounded,
                        accent: AppColors.signal,
                        haptic: PressHaptic.selection,
                        onPressed: () => _onAnswer(AnswerType.yes),
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'No',
                              variant: AppButtonVariant.secondary,
                              accent: AppColors.textMuted,
                              haptic: PressHaptic.selection,
                              onPressed: () => _onAnswer(AnswerType.no),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Expanded(
                            child: AppButton(
                              label: 'Not sure',
                              variant: AppButtonVariant.secondary,
                              accent: AppColors.riskModerate,
                              haptic: PressHaptic.selection,
                              onPressed: () => _onAnswer(AnswerType.unsure),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionText extends StatelessWidget {
  const _QuestionText({super.key, required this.parts});

  final (String, String, String) parts;

  @override
  Widget build(BuildContext context) {
    final (prefix, keyword, suffix) = parts;

    if (keyword.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Text(prefix, style: AppText.h1),
      );
    }

    return Column(
      // Stretch, not start: the AnimatedSwitcher above lays its children out
      // in a Stack, which shrink-wraps this column and then centres it — so a
      // left-aligned question ends up floating off the page gutter.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prefix, style: AppText.bodyMuted),
        const SizedBox(height: AppTheme.space8),
        // The symptom itself, set large — the one thing on screen the user
        // actually has to judge.
        Text('$keyword$suffix', style: AppText.display),
      ],
    );
  }
}

/// "Why are we asking?" — collapsed by default, because most people want to
/// answer and move on, and expandable because the ones who do not want a
/// reason want it right now.
class _WhyCard extends StatelessWidget {
  const _WhyCard({
    required this.reason,
    required this.expanded,
    required this.onToggle,
  });

  final String reason;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: expanded ? AppColors.pulse : null,
      onTap: onToggle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 17,
                color: expanded ? AppColors.pulse : AppColors.textFaint,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Text(
                  'Why we ask',
                  style: AppText.label.copyWith(
                    color: expanded ? AppColors.pulse : AppColors.textMuted,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: AppTheme.quick,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: expanded ? AppColors.pulse : AppColors.textFaint,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: AppTheme.quick,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppTheme.space12),
              child: Text(reason, style: AppText.bodySm),
            ),
          ),
        ],
      ),
    );
  }
}

/// The waiting state between answering and the next question.
///
/// It occupies the height the answer buttons had, so the page does not jump
/// when the answer is sent and again when the next question lands.
class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Text('Reading your answer', style: AppText.bodySm),
        ],
      ),
    );
  }
}
