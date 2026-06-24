import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';

enum TriageStage { symptoms, assessment, results }

class StageTracker extends StatelessWidget {
  final TriageStage currentStage;

  const StageTracker({super.key, required this.currentStage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      child: Row(
        children: [
          _buildStageNode('Symptoms', TriageStage.symptoms),
          _buildConnectingLine(TriageStage.assessment),
          _buildStageNode('Assessment', TriageStage.assessment),
          _buildConnectingLine(TriageStage.results),
          _buildStageNode('Results', TriageStage.results),
        ],
      ),
    );
  }

  Widget _buildConnectingLine(TriageStage stageRequired) {
    // A line is 'completed' if we have reached or passed the stage it points to.
    final isCompleted = currentStage.index >= stageRequired.index;
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? AppColors.ink : AppColors.border,
      ),
    );
  }

  Widget _buildStageNode(String label, TriageStage stage) {
    final isCompleted = currentStage.index > stage.index;
    final isCurrent = currentStage == stage;

    Color dotColor;
    Color dotBorderColor;
    TextStyle labelStyle;

    if (isCompleted) {
      dotColor = AppColors.ink;
      dotBorderColor = AppColors.ink;
      labelStyle = AppText.dataLabel.copyWith(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700);
    } else if (isCurrent) {
      dotColor = AppColors.ink;
      dotBorderColor = AppColors.ink;
      labelStyle = AppText.dataValue.copyWith(fontSize: 12, fontWeight: FontWeight.bold);
    } else {
      dotColor = Colors.transparent;
      dotBorderColor = AppColors.border;
      labelStyle = AppText.dataLabel.copyWith(color: AppColors.inkMuted, fontSize: 12);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: dotBorderColor, width: 2),
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(label.toUpperCase(), style: labelStyle),
      ],
    );
  }
}
