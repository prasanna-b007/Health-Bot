import 'package:flutter/material.dart';
import '../models/assessment_data.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/assessment_tag_card.dart';
import 'symptom_input_screen.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _ageController = TextEditingController();
  String _selectedDuration = '1 day';
  int _severity = 5;

  final List<String> _durationOptions = ['1 day', '2-3 days', '4-7 days', '>1 week'];

  void _onNext() {
    int age = int.tryParse(_ageController.text) ?? 30;
    final data = AssessmentData(
      age: age,
      duration: _selectedDuration,
      severity: _severity,
    );
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SymptomInputScreen(data: data),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
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
            statusWord: 'step 1',
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient Age', style: AppText.heading),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: AppText.dataValue,
                    decoration: InputDecoration(
                      hintText: 'e.g. 30',
                      hintStyle: AppText.dataValue.copyWith(color: AppColors.inkMuted),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.ink),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Symptom Duration', style: AppText.heading),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _durationOptions.map((duration) {
                      final isSelected = _selectedDuration == duration;
                      return ChoiceChip(
                        label: Text(duration, style: isSelected ? AppText.dataValue.copyWith(color: AppColors.surface) : AppText.dataValue),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedDuration = duration);
                        },
                        selectedColor: AppColors.ink,
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: isSelected ? AppColors.ink : AppColors.border),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Severity (1-10)', style: AppText.heading),
                      Text('$_severity', style: AppText.dataValue),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.ink,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.ink,
                      overlayColor: AppColors.ink.withAlpha(32),
                      trackHeight: 2.0,
                    ),
                    child: Slider(
                      value: _severity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() => _severity = value.toInt());
                      },
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Next', style: AppText.body.copyWith(color: AppColors.surface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
