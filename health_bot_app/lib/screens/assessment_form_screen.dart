import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assessment_data.dart';
import '../models/health_profile.dart';
import '../motion/pressable.dart';
import '../services/health_store.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/inputs.dart';
import '../widgets/ui.dart';
import 'profile_screen.dart';
import 'symptom_input_screen.dart';

/// Step one: the three facts that shape every later question.
///
/// When a profile exists, age arrives prefilled and is labelled as such. It is
/// prefilled, never assumed — the field stays editable and the user confirms
/// it by continuing, because age moves the risk score and a silently inherited
/// value is exactly the failure the previous hardcoded default caused.
class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _ageController = TextEditingController();
  final _ageFocus = FocusNode();

  SymptomDuration _duration = SymptomDuration.twoToThreeDays;
  int _severity = 5;

  /// Errors stay hidden until the field has been visited or a submit
  /// attempted, so an untouched form does not greet the user in red.
  bool _ageTouched = false;

  /// True while the field still holds exactly what the profile supplied.
  /// Clears the moment the user edits, so the "from your profile" note cannot
  /// keep vouching for a number they have since changed.
  bool _agePrefilled = false;

  @override
  void initState() {
    super.initState();
    final profileAge = HealthStore.instance.profile.age;
    if (profileAge != null) {
      _ageController.text = profileAge.toString();
      _agePrefilled = true;
    }
    _ageController.addListener(_onAgeChanged);
    _ageFocus.addListener(() {
      if (!_ageFocus.hasFocus && _ageController.text.isNotEmpty) {
        setState(() => _ageTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _ageController.removeListener(_onAgeChanged);
    _ageController.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  void _onAgeChanged() {
    final profileAge = HealthStore.instance.profile.age;
    setState(() {
      _agePrefilled =
          profileAge != null && _ageController.text.trim() == '$profileAge';
    });
  }

  String? get _ageError =>
      _ageTouched ? AssessmentData.validateAge(_ageController.text) : null;

  bool get _canContinue => AssessmentData.isValidAge(_ageController.text);

  /// Plain-language note on how this age changes the assessment. Age silently
  /// moves the risk score, so saying it out loud makes a typo visible before
  /// it reaches the result.
  String? get _ageContext {
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || !_canContinue) return null;
    if (age <= 2) return 'Infants are assessed with extra caution.';
    if (age <= 12) return 'Assessed using guidance for children.';
    if (age >= 60) return 'Age is treated as an added risk factor.';
    return null;
  }

  void _onContinue() {
    setState(() => _ageTouched = true);
    if (!_canContinue) {
      _ageFocus.requestFocus();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SymptomInputScreen(
          data: AssessmentData(
            age: int.parse(_ageController.text.trim()),
            duration: _duration,
            severity: _severity,
          ),
        ),
      ),
    );
  }

  Color get _severityColor => _severity <= 3
      ? AppColors.riskLow
      : _severity <= 6
      ? AppColors.riskModerate
      : AppColors.riskHigh;

  String get _severityWord => switch (_severity) {
    <= 2 => 'Barely noticeable',
    <= 4 => 'Mild',
    <= 6 => 'Uncomfortable',
    <= 8 => 'Hard to ignore',
    _ => 'Severe',
  };

  @override
  Widget build(BuildContext context) {
    final profile = HealthStore.instance.profile;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AppTopBar(
              title: 'About you',
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
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
                Text('Three quick things', style: AppText.display),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'These shape the questions you get asked next.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: AppTheme.space32),

                // ── Age ──────────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('How old are you?', style: AppText.h2),
                          ),
                          if (_agePrefilled)
                            const StatusPill(
                              'From profile',
                              color: AppColors.pulse,
                              icon: Icons.person_outline_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space16),
                      AppTextField(
                        controller: _ageController,
                        focusNode: _ageFocus,
                        hint: 'e.g. 34',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onSubmitted: (_) => setState(() => _ageTouched = true),
                        errorText: _ageError,
                        helperText: _ageContext,
                        // The same field as the one on the profile screen,
                        // down to the unit on the right. Setting this one in a
                        // display size made a two-digit answer look like the
                        // headline of the screen.
                        suffix: Text('years', style: AppText.bodySm),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space16),

                // ── Duration ─────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'How long has this been going on?',
                        style: AppText.h2,
                      ),
                      const SizedBox(height: AppTheme.space16),
                      ChoiceRow<SymptomDuration>(
                        options: SymptomDuration.values,
                        selected: _duration,
                        labelOf: (d) => d.label,
                        onChanged: (d) => setState(() => _duration = d),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space16),

                // ── Severity ─────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'How bad does it feel?',
                              style: AppText.h2,
                            ),
                          ),
                          Text(
                            '$_severity of 10',
                            style: AppText.value.copyWith(
                              color: _severityColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space16),
                      _SeverityScale(
                        value: _severity,
                        color: _severityColor,
                        onChanged: (v) => setState(() => _severity = v),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      Text(
                        _severityWord,
                        style: AppText.bodySm.copyWith(
                          color: _severityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // A profile with medical history is worth repeating back
                // here — it is context the user should carry into the
                // description they are about to write.
                if (profile.contextLines.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space24),
                  _ProfileContext(profile: profile),
                ],
              ],
            ),
          ),
          BottomActionBar(
            child: AppButton(
              label: 'Continue',
              trailingIcon: Icons.arrow_forward_rounded,
              // Disabled until a usable age is present, so the gate is
              // visible rather than a tap that quietly does nothing.
              onPressed: _canContinue ? _onContinue : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable 1–10 scale.
///
/// It is a row of targets rather than a slider: a slider on a phone means
/// dragging a 12px thumb accurately, while these can be hit directly, and the
/// height ramp communicates the scale's direction without a legend.
class _SeverityScale extends StatelessWidget {
  const _SeverityScale({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= 10; i++) ...[
                if (i > 1) const SizedBox(width: 7),
                Expanded(
                  child: Pressable(
                    haptic: PressHaptic.selection,
                    pressedScale: 0.9,
                    onTap: () => onChanged(i),
                    child: SizedBox(
                      // Full-height hit area regardless of the bar drawn in it.
                      height: 52,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: AppTheme.quick,
                          curve: Curves.easeOut,
                          height: 20 + (i / 10) * 24,
                          decoration: BoxDecoration(
                            // The whole run up to the chosen number fills, so
                            // the reading is "six out of ten" and not a single
                            // marker floating on an empty track.
                            color: i <= value ? color : AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mild', style: AppText.caption),
            Text('Severe', style: AppText.caption),
          ],
        ),
      ],
    );
  }
}

class _ProfileContext extends StatelessWidget {
  const _ProfileContext({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('From your profile', style: AppText.label)),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textFaint,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          for (final line in profile.contextLines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line, style: AppText.bodySm),
            ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Your conditions are sent with the assessment and affect your risk '
            'score. Allergies and medications stay on this device.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
