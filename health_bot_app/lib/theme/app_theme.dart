import 'package:flutter/material.dart';
import 'colors.dart';

/// Shape, spacing and depth.
///
/// Depth here is almost nothing on purpose: a white card on warm paper with
/// one hairline border is already separate, and the faint shadow below it only
/// settles it onto the page. The previous design stacked coloured blooms to
/// do the same job, and every surface ended up glowing.
class AppTheme {
  // ── Radii ───────────────────────────────────────────────────────────────
  // Softened, not rounded off. Big radii on small elements is the tell of a
  // design that was never drawn at real size.
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 20.0;
  static const double radiusPill = 999.0;

  // ── Spacing ─────────────────────────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space56 = 56.0;

  /// The page gutter. Every screen's content starts here.
  static const double gutter = 20.0;

  // ── Depth ───────────────────────────────────────────────────────────────
  /// A resting card. One short, soft shadow — enough to lift the white off
  /// the paper, not enough to notice on its own.
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(color: Color(0x0A1C1B18), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// A sheet or a menu floating over the page.
  static List<BoxShadow> get floatShadow => const [
    BoxShadow(color: Color(0x141C1B18), blurRadius: 24, offset: Offset(0, -4)),
  ];

  // ── Borders ─────────────────────────────────────────────────────────────
  /// The default 1px edge of a card, a field, an unselected chip.
  static Border get hairline =>
      Border.all(color: AppColors.stroke, width: AppColors.strokeWidth);

  /// The edge of something selected, active or urgent, in its own colour.
  static Border accentBorder(
    Color color, {
    double alpha = 0.4,
    double width = 1,
  }) => Border.all(
    color: color.withValues(alpha: alpha),
    width: width,
  );

  // ── Motion ──────────────────────────────────────────────────────────────
  /// A small state change: selection, colour, a chip filling in.
  static const Duration quick = Duration(milliseconds: 150);

  /// Content arriving or replacing content.
  static const Duration medium = Duration(milliseconds: 240);
}
