import 'package:flutter/material.dart';

import '../models/assessment_data.dart';
import '../motion/pressable.dart';
import '../services/api_service.dart';
import '../services/health_store.dart';
import '../services/red_flags.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/inputs.dart';
import '../widgets/ui.dart';
import '../widgets/stage_tracker.dart';
import 'dynamic_triage_screen.dart';
import 'crisis_screen.dart';
import 'hospital_finder_screen.dart';
import 'results_screen.dart';

/// Step two: what is actually wrong, in the user's own words.
///
/// The free-text field leads and the quick-add chips assist it, rather than the
/// other way round. A fixed symptom picker would quietly cap what the backend
/// ever sees, and the interview that follows is built to work from a sentence.
class SymptomInputScreen extends StatefulWidget {
  const SymptomInputScreen({super.key, required this.data, this.apiService});

  final AssessmentData data;

  /// Injectable so the offline red-flag fallback can be tested against a
  /// failing server. When null the screen owns its own instance, which is the
  /// production path — one ApiService is one Rasa conversation, and it is
  /// handed to the interview screen so the session's slots carry across.
  final ApiService? apiService;

  @override
  State<SymptomInputScreen> createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  final _controller = TextEditingController();
  late final ApiService _apiService = widget.apiService ?? ApiService();

  /// Only an instance this screen created is this screen's to close.
  bool get _ownsApiService => widget.apiService == null;

  bool _isLoading = false;

  static const _common = [
    'Fever',
    'Cough',
    'Fatigue',
    'Chills',
    'Headache',
    'Nausea',
    'Sore throat',
    'Shortness of breath',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsApiService) _apiService.dispose();
    super.dispose();
  }

  bool _mentions(String symptom) =>
      _controller.text.toLowerCase().contains(symptom.toLowerCase());

  /// Quick-add chips edit the sentence rather than maintaining a parallel
  /// selection, so what the user sees in the field is exactly what gets sent.
  void _toggle(String symptom) {
    final term = symptom.toLowerCase();
    final current = _controller.text.trim();

    if (_mentions(symptom)) {
      // Remove the term and tidy up whatever conjunction it left behind.
      var next = current
          .replaceAll(RegExp('\\band\\s+$term\\b', caseSensitive: false), '')
          .replaceAll(RegExp('\\b$term\\s+and\\b', caseSensitive: false), '')
          .replaceAll(RegExp('\\b$term\\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*,\s*,'), ',')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      next = next.replaceAll(RegExp(r'^(and|,)\s*', caseSensitive: false), '');
      next = next.replaceAll(RegExp(r'\s*(and|,)$', caseSensitive: false), '');
      _controller.text = next;
      return;
    }

    _controller.text = current.isEmpty ? term : '$current and $term';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_isLoading;

  Future<void> _onSubmit() async {
    final symptoms = _controller.text.trim();
    if (symptoms.isEmpty) return;

    setState(() => _isLoading = true);
    widget.data.symptoms = symptoms;

    final response = await _apiService.sendSymptoms(
      widget.data,
      conditions: HealthStore.instance.profile.conditions,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.hasError) {
      // The server is the real red-flag detector. When it cannot be reached,
      // check the text here rather than leaving someone who just typed
      // "crushing chest pain" looking at a connection error.
      // Crisis first: a disclosure and a heart attack in the same sentence
      // must reach a crisis line, not a hospital map.
      if (RedFlags.hasCrisis(symptoms)) {
        _goToCrisis();
        return;
      }
      final flag = RedFlags.findIn(symptoms);
      if (flag != null) {
        _goToEmergency(RedFlags.reasonFor(flag));
        return;
      }
      _showError(response.errorMessage!);
      return;
    }

    if (response.isCrisis) {
      _goToCrisis();
    } else if (response.isEmergency) {
      _goToEmergency(
        response.emergencyReason ?? 'Emergency symptoms detected.',
      );
    } else if (response.result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultsScreen(data: widget.data, result: response.result!),
        ),
      );
    } else if (response.nextQuestion != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DynamicTriageScreen(
            data: widget.data,
            // The same instance, so the Rasa session (and its slots) carries
            // across screens instead of starting over.
            apiService: _apiService,
            currentQuestion: response.nextQuestion!,
          ),
        ),
      );
    }
  }

  /// Hands off to emergency guidance. Replaces this screen rather than
  /// stacking on it: going "back" from an emergency to a half-filled symptom
  /// form is not a journey anyone needs.
  void _goToEmergency(String reason) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => HospitalFinderScreen(emergencyReason: reason),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// Hands off to crisis support. A separate destination from
  /// [_goToEmergency] on purpose: someone who has disclosed suicidal thoughts
  /// needs a crisis line, not a map of emergency departments.
  void _goToCrisis() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const CrisisScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = HealthStore.instance.profile;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AppTopBar(
              title: 'Your symptoms',
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).pop(),
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
            child: const StageTracker(currentStage: TriageStage.symptoms),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space24,
                AppTheme.gutter,
                AppTheme.space32,
              ),
              children: [
                Text('Describe what you feel', style: AppText.display),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'Everyday words are fine. The interview that follows will '
                  'narrow it down.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: AppTheme.space24),

                AppTextField(
                  controller: _controller,
                  hint: 'e.g. fever and a headache since Sunday',
                  minLines: 3,
                  maxLines: 6,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppTheme.space24),
                const SectionHeading('Or tap a common symptom'),
                const SizedBox(height: AppTheme.space12),
                Wrap(
                  spacing: AppTheme.space8,
                  runSpacing: AppTheme.space8,
                  children: [
                    for (final symptom in _common)
                      _SymptomChip(
                        label: symptom,
                        selected: _mentions(symptom),
                        onTap: () => _toggle(symptom),
                      ),
                  ],
                ),

                if (profile.contextLines.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space24),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space20,
                      vertical: AppTheme.space16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medical_information_outlined,
                          size: 17,
                          color: AppColors.pulse,
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your health history', style: AppText.label),
                              const SizedBox(height: 5),
                              for (final line in profile.contextLines)
                                Text(line, style: AppText.bodySm),
                              const SizedBox(height: 6),
                              Text(
                                'Conditions are included automatically.',
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          BottomActionBar(
            child: AppButton(
              label: 'Analyse symptoms',
              trailingIcon: Icons.arrow_forward_rounded,
              loading: _isLoading,
              onPressed: _canSubmit ? _onSubmit : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quick-add chip. Selected state means "this word is in your description",
/// which is why tapping it again takes the word back out.
class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: PressHaptic.selection,
      pressedScale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.quick,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.wash(AppColors.signal, 0.10)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected
                ? AppColors.signal.withValues(alpha: 0.45)
                : AppColors.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : Icons.add_rounded,
              size: 14,
              color: selected ? AppColors.signal : AppColors.textFaint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.body.copyWith(
                fontSize: 13.5,
                color: selected ? AppColors.signal : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
