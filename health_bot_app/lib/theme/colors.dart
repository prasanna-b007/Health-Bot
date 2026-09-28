import 'package:flutter/material.dart';

/// The palette.
///
/// A symptom checker is read by someone who is worried, often quickly, often
/// one-handed. So the page is warm paper and the content sits on plain white
/// cards — the same arrangement as a printed form, which is a thing people
/// already know how to read.
///
/// Three rules keep it honest:
///  - Colour means something. Grey is the default; a coloured element is a
///    risk level, a live state, or the one action the screen is for.
///  - Separation comes from a hairline border and a shade of background,
///    never from a heavy shadow or a glow.
///  - Red belongs to emergencies alone. Nothing decorative may borrow it.
class AppColors {
  // ── Paper ───────────────────────────────────────────────────────────────
  /// Page background. Slightly warm; a pure grey reads cold and clinical in
  /// the wrong way.
  static const Color canvas = Color(0xFFF7F6F2);

  /// Cards, sheets, the app bar.
  static const Color surface = Color(0xFFFFFFFF);

  /// Recessed areas inside a card: text fields, unselected chips, empty
  /// meter track.
  static const Color surfaceRaised = Color(0xFFF2F0EB);

  /// A pressed or hovered surface.
  static const Color surfaceHigh = Color(0xFFE9E6DF);

  // ── Accent ──────────────────────────────────────────────────────────────
  /// Deep pine. The primary action, focus rings, anything selected. Dark
  /// enough to carry white text at any size.
  static const Color signal = Color(0xFF15695A);

  /// A pale wash of [signal] for fills behind its own text or icon.
  static const Color signalDim = Color(0xFFE6F0ED);

  /// Muted indigo — secondary information: the specialist, "why we ask",
  /// anything drawn from the user's own profile.
  static const Color pulse = Color(0xFF41568C);

  // ── Risk ────────────────────────────────────────────────────────────────
  // One green→amber→red escalation, each dark enough to read as text on
  // white without a bolder weight propping it up.
  static const Color riskLow = Color(0xFF2E7D57);
  static const Color riskModerate = Color(0xFFA96A12);
  static const Color riskHigh = Color(0xFFB23A2C);

  /// Emergency. The same red as [riskHigh] on purpose — high risk and an
  /// emergency are one escalating channel, not two competing ones.
  static const Color ember = Color(0xFFB23A2C);

  // ── Ink ─────────────────────────────────────────────────────────────────
  /// Body and headings. Warm near-black; pure black on warm paper looks like
  /// a hole punched in the page.
  static const Color text = Color(0xFF1C1B18);

  /// Supporting copy and descriptions.
  static const Color textMuted = Color(0xFF5F5D56);

  /// Captions, units, timestamps, disabled labels.
  static const Color textFaint = Color(0xFF8B887F);

  /// Text on a filled accent.
  static const Color textInverse = Color(0xFFFFFFFF);

  // ── Lines ───────────────────────────────────────────────────────────────
  /// The card and field border. One warm hairline does the work a stack of
  /// shadows used to.
  static const Color stroke = Color(0xFFE5E1D8);

  /// A slightly firmer edge, for an element that needs to hold its own
  /// against a card sitting behind it.
  static const Color strokeStrong = Color(0xFFD6D1C6);

  /// Divider inside a card, lighter than the card's own border.
  static const Color divider = Color(0xFFEDEAE3);

  static const double strokeWidth = 1.0;

  /// Behind a modal sheet.
  static Color get scrim => const Color(0xFF1C1B18).withValues(alpha: 0.32);

  /// A colour thinned to a tint, for a fill sitting under its own full
  /// strength text or icon.
  static Color wash(Color color, [double alpha = 0.10]) =>
      Color.alphaBlend(color.withValues(alpha: alpha), surface);

  // ── Risk lookup ─────────────────────────────────────────────────────────
  /// The colour for a risk string from the backend. Central, so every screen
  /// showing a risk level agrees on what it looks like.
  static Color forRisk(String level) => switch (level.toLowerCase()) {
    'low' => riskLow,
    'moderate' || 'medium' => riskModerate,
    'high' => riskHigh,
    'emergency' => ember,
    _ => riskModerate,
  };
}
