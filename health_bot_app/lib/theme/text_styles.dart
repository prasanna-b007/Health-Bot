import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppText {
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.text,
      );

  // Added line height 1.4-1.5 for wizard question text
  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600, // SemiBold
        color: AppColors.text,
        height: 1.4,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600, // SemiBold
        color: AppColors.text,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Regular
        color: AppColors.text,
      );

  static TextStyle get bodyMuted => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.subtext,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.subtext,
      );

  static TextStyle get dataLabel => GoogleFonts.ibmPlexMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.subtext,
        letterSpacing: 0.2, // Default tightened
      );

  static TextStyle get dataValue => GoogleFonts.ibmPlexMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get dataValueMuted => GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.inkMuted,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // Aliases for compatibility
  static TextStyle get heading => h2;
}
