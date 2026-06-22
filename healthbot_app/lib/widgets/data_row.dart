import 'package:flutter/material.dart';
import '../theme/text_styles.dart';

class TagDataRow extends StatelessWidget {
  final String label;
  final String value;

  const TagDataRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.dataLabel),
          Text(value, style: AppText.dataValue),
        ],
      ),
    );
  }
}
