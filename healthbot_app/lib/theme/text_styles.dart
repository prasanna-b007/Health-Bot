import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppText {
  static TextStyle get dataLabel => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        color: AppColors.inkMuted,
        letterSpacing: 0.4,
      );

  static TextStyle get dataValue => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.ink,
        height: 1.5,
      );

  static TextStyle get bodyMuted => GoogleFonts.inter(
        fontSize: 13,
        color: AppColors.inkMuted,
        height: 1.5,
      );

  static TextStyle get heading => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );
}
