import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assessment_data.dart';
import '../models/health_profile.dart';
import '../services/health_store.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/inputs.dart';
import '../widgets/ui.dart';
import 'assessment_form_screen.dart';
import 'hospital_finder_screen.dart';

/// Where the app's memory of the user is edited.
///
/// Every field is optional and the screen says so, once, at the bottom: this
/// is a convenience that removes repeated typing, not a registration form. It
/// never blocks on being filled in.
///
/// Edits are held locally and committed by an explicit Save. Auto-saving each
/// keystroke would be tidier to implement but leaves no way to abandon a
/// half-typed change, and a medical profile is exactly the thing someone might
/// start editing and think better of.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isFirstRun = false});

  final bool isFirstRun;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _store = HealthStore.instance;

  late final TextEditingController _name;
  late final TextEditingController _age;
  final _ageFocus = FocusNode();

  late ProfileSex _sex;
  late List<String> _conditions;
  late List<String> _allergies;
  late List<String> _medications;

  late final TextEditingController _smokingHistory;
  late final TextEditingController _alcoholHistory;
  late final TextEditingController _drugHistory;

  bool _dirty = false;
  bool _ageTouched = false;

  @override
  void initState() {
    super.initState();
    final p = _store.profile;
    _name = TextEditingController(text: p.name ?? '')..addListener(_markDirty);
    _age = TextEditingController(text: p.age?.toString() ?? '')
      ..addListener(_markDirty);
    _sex = p.sex;
    _conditions = [...p.conditions];
    _allergies = [...p.allergies];
    _medications = [...p.medications];
    _smokingHistory = TextEditingController(text: p.smokingHistory ?? '')
      ..addListener(_markDirty);
    _alcoholHistory = TextEditingController(text: p.alcoholHistory ?? '')
      ..addListener(_markDirty);
    _drugHistory = TextEditingController(text: p.drugHistory ?? '')
      ..addListener(_markDirty);
    _ageFocus.addListener(() {
      if (!_ageFocus.hasFocus && mounted) setState(() => _ageTouched = true);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _smokingHistory.dispose();
    _alcoholHistory.dispose();
    _drugHistory.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (mounted) setState(() => _dirty = true);
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  /// Age is the one field with a wrong answer, because it is the one that
  /// reaches the risk engine. Blank is fine; a number outside human range is
  /// not.
  String? get _ageError {
    final raw = _age.text.trim();
    if (raw.isEmpty) return null;
    if (!_ageTouched) return null;
    return AssessmentData.validateAge(raw);
  }

  bool get _canSave => _ageError == null;

  HealthProfile get _edited => HealthProfile(
    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
    age: int.tryParse(_age.text.trim()),
    sex: _sex,
    conditions: _conditions,
    allergies: _allergies,
    medications: _medications,
    smokingHistory: _smokingHistory.text.trim().isEmpty
        ? null
        : _smokingHistory.text.trim(),
    alcoholHistory: _alcoholHistory.text.trim().isEmpty
        ? null
        : _alcoholHistory.text.trim(),
    drugHistory: _drugHistory.text.trim().isEmpty
        ? null
        : _drugHistory.text.trim(),
  );

  Future<void> _save() async {
    setState(() => _ageTouched = true);
    if (!_canSave) {
      _ageFocus.requestFocus();
      return;
    }
    await _store.saveProfile(_edited);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved on this device')),
    );
    if (widget.isFirstRun) {
      await _store.markOnboarded();
      if (!mounted) return;
      // Continue to the symptom check — HomeScreen is already beneath.
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentFormScreen()));
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Leaves the welcome screen without saving anything, for good.
  ///
  /// Every field is optional, but the only way past the welcome screen used
  /// to be the button at the bottom of the form — and leaving the form empty
  /// meant seeing it again on every launch, because "onboarded" was inferred
  /// from the profile having something in it.
  Future<void> _skip() async {
    await _store.markOnboarded();
    if (!mounted) return;
    // Continue to the symptom check — HomeScreen is already beneath.
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentFormScreen()));
  }

  /// Emergency help before any form. Someone opening the app for the first
  /// time in an emergency must not have to fill in or skip anything first.
  void _openEmergency() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HospitalFinderScreen(
          emergencyReason: 'You opened emergency help from the welcome screen.',
        ),
      ),
    );
  }

  /// Back from an edited profile asks before discarding the edits.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Discard changes?', style: AppText.h2),
        content: Text(
          'Your edits to the profile have not been saved.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _onBack() {
    if (_dirty) {
      _confirmDiscard();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text('Erase profile?', style: AppText.h2),
        content: Text(
          'Your name, age and medical history will be removed from this '
          'device. Saved assessments are not affected.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppText.body.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Erase',
              style: AppText.body.copyWith(
                color: AppColors.ember,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _store.clearProfile();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isFirstRun || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: AppTopBar(
                title: widget.isFirstRun ? 'Welcome' : 'Your profile',
                leading: widget.isFirstRun
                    ? const SizedBox.shrink()
                    : AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: _onBack,
                      ),
                actions: [
                  if (widget.isFirstRun)
                    AppButton(
                      label: 'Skip',
                      variant: AppButtonVariant.ghost,
                      fullWidth: false,
                      compact: true,
                      onPressed: _skip,
                    ),
                ],
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
                  if (widget.isFirstRun) ...[
                    _WelcomeEmergency(onTap: _openEmergency),
                    const SizedBox(height: AppTheme.space24),
                  ],
                  const SectionHeading('Identity'),
                  const SizedBox(height: AppTheme.space16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Name', style: AppText.h3),
                        const SizedBox(height: AppTheme.space4),
                        Text('Used only to greet you.', style: AppText.bodySm),
                        const SizedBox(height: AppTheme.space12),
                        AppTextField(
                          controller: _name,
                          hint: 'First name',
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppTheme.space24),
                        Text('Age', style: AppText.h3),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Prefills your assessment. Age changes how risk is scored.',
                          style: AppText.bodySm,
                        ),
                        const SizedBox(height: AppTheme.space12),
                        AppTextField(
                          controller: _age,
                          focusNode: _ageFocus,
                          hint: 'e.g. 34',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          errorText: _ageError,
                          suffix: Text('years', style: AppText.bodySm),
                        ),
                        const SizedBox(height: AppTheme.space24),
                        Text('Sex', style: AppText.h3),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Some conditions present differently. Optional.',
                          style: AppText.bodySm,
                        ),
                        const SizedBox(height: AppTheme.space12),
                        ChoiceRow<ProfileSex>(
                          options: ProfileSex.values,
                          selected: _sex,
                          accent: AppColors.pulse,
                          labelOf: (s) => s.label,
                          onChanged: (s) => _update(() => _sex = s),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),

                  const SectionHeading('Medical history'),
                  const SizedBox(height: AppTheme.space16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TagBlock(
                          title: 'Ongoing conditions',
                          note: 'Asthma, diabetes, hypertension…',
                          hint: 'Add a condition',
                          values: _conditions,
                          accent: AppColors.pulse,
                          onChanged: (v) => _update(() => _conditions = v),
                        ),
                        const SizedBox(height: AppTheme.space24),
                        _TagBlock(
                          title: 'Allergies',
                          note: 'Including drug allergies.',
                          hint: 'Add an allergy',
                          values: _allergies,
                          accent: AppColors.riskModerate,
                          onChanged: (v) => _update(() => _allergies = v),
                        ),
                        const SizedBox(height: AppTheme.space24),
                        _TagBlock(
                          title: 'Current medications',
                          note: 'What you take regularly.',
                          hint: 'Add a medication',
                          values: _medications,
                          accent: AppColors.signal,
                          onChanged: (v) => _update(() => _medications = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),

                  const SectionHeading('Lifestyle'),
                  const SizedBox(height: AppTheme.space16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Smoking', style: AppText.h3),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Do you smoke, for how long, or in the past?',
                          style: AppText.bodySm,
                        ),
                        const SizedBox(height: AppTheme.space12),
                        AppTextField(
                          controller: _smokingHistory,
                          hint: 'e.g. Never, or 10 years',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppTheme.space24),

                        Text('Alcohol', style: AppText.h3),
                        const SizedBox(height: AppTheme.space4),
                        Text('Do you drink alcohol?', style: AppText.bodySm),
                        const SizedBox(height: AppTheme.space12),
                        AppTextField(
                          controller: _alcoholHistory,
                          hint: 'e.g. Occasionally',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppTheme.space24),

                        Text('Drugs', style: AppText.h3),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Do you use recreational drugs?',
                          style: AppText.bodySm,
                        ),
                        const SizedBox(height: AppTheme.space12),
                        AppTextField(
                          controller: _drugHistory,
                          hint: 'e.g. None',
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.space24),
                  const _PrivacyNote(),

                  const SizedBox(height: AppTheme.space24),
                  AppButton(
                    label: widget.isFirstRun
                        ? 'Continue to App'
                        : (_dirty ? 'Save profile' : 'Saved'),
                    icon: widget.isFirstRun
                        ? Icons.arrow_forward_rounded
                        : (_dirty ? Icons.check_rounded : null),
                    onPressed: (widget.isFirstRun || _dirty) ? _save : null,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  if (_store.profile.isConfigured && !widget.isFirstRun)
                    AppButton(
                      label: 'Erase profile',
                      variant: AppButtonVariant.ghost,
                      onPressed: _confirmClear,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The welcome screen's way straight to emergency care, above the form.
class _WelcomeEmergency extends StatelessWidget {
  const _WelcomeEmergency({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.ember,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Need help right now?',
            style: AppText.label.copyWith(color: AppColors.ember),
          ),
          const SizedBox(height: AppTheme.space12),
          AppButton(
            label: 'Emergency help',
            icon: Icons.emergency_outlined,
            variant: AppButtonVariant.danger,
            onPressed: onTap,
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Everything below is optional. Skip it and come back any time.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _TagBlock extends StatelessWidget {
  const _TagBlock({
    required this.title,
    required this.note,
    required this.hint,
    required this.values,
    required this.onChanged,
    required this.accent,
  });

  final String title;
  final String note;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppText.h3)),
            if (values.isNotEmpty)
              Text('${values.length}', style: AppText.bodySm),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        Text(note, style: AppText.bodySm),
        const SizedBox(height: AppTheme.space12),
        TagEditor(
          values: values,
          onChanged: onChanged,
          hint: hint,
          accent: accent,
        ),
      ],
    );
  }
}

/// Said plainly, once. A profile that stores conditions and medications earns
/// a clear statement of where that goes — and here the honest answer is
/// "nowhere".
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 15,
          color: AppColors.textFaint,
        ),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: Text(
            'Stored on this phone. Your age and ongoing conditions are sent '
            'with an assessment, because they change how your risk is scored. '
            'Your name, allergies and medications are never sent anywhere.',
            style: AppText.caption,
          ),
        ),
      ],
    );
  }
}
