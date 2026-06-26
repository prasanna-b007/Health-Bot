import 'package:flutter/material.dart';
import '../theme/text_styles.dart';

class TagDataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMuted;

  const TagDataRow({
    super.key,
    required this.label,
    required this.value,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // Kept at 4.0 to maintain dense rhythm for data tables
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.dataLabel.copyWith(
            letterSpacing: label.length <= 4 ? 0.4 : 0.2,
          )),
          Expanded(
            flex: 3, 
            child: Text(
              value, 
              style: isMuted ? AppText.dataValueMuted : AppText.dataValue,
            ),
          ),
        ],
      ),
    );
  }
}
