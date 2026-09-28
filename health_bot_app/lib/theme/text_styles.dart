import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Type.
///
/// One family, Inter, at every size. The previous design ran three — a
/// geometric display face, a body face and a monospace for every number — and
/// the mix is what made plain sentences look like readings off a machine.
/// A single humanist sans, sized carefully, is what most well-made apps
/// actually use.
///
/// Numbers that a person might compare between two rows still get tabular
/// figures, so a changing digit does not shift the text beside it. That is
/// the one thing the monospace was genuinely for.
class AppText {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ── Headings ────────────────────────────────────────────────────────────
  /// The line that opens a screen. One per screen.
  static TextStyle get display => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    letterSpacing: -0.6,
    height: 1.25,
  );

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    letterSpacing: -0.35,
    height: 1.3,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // ── Copy ────────────────────────────────────────────────────────────────
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
    height: 1.55,
  );

  static TextStyle get bodyMuted => body.copyWith(color: AppColors.textMuted);

  static TextStyle get bodySm => GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.5,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
    height: 1.45,
  );

  // ── Small text ──────────────────────────────────────────────────────────
  /// A section heading or a field label. Sentence case at a readable size —
  /// not tracked-out uppercase, which is a costume rather than a hierarchy.
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// A value set beside a [label].
  static TextStyle get value => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    height: 1.4,
    fontFeatures: _tabular,
  );

  /// A figure that is the point of its own row — a count, an age, a distance.
  static TextStyle get readout => GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    letterSpacing: -0.8,
    height: 1.05,
    fontFeatures: _tabular,
  );

  /// Inside a pill or a chip.
  static TextStyle get tag => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    height: 1.3,
    letterSpacing: 0.1,
  );
}
