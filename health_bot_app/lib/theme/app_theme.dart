import 'package:flutter/material.dart';

class AppTheme {
  static const double radiusBorder = 16.0;
  static const double radiusCard = 20.0;
  static const double radiusButton = 14.0;
  
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  static List<BoxShadow> get premiumShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04), // Deep Navy shadow
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ];
}
