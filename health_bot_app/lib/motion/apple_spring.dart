import 'dart:math' as math;
import 'package:flutter/physics.dart';

/// Apple's designer-friendly spring parameters — damping ratio + response —
/// translated to a Flutter [SpringDescription].
///
/// damping: 1.0 = critically damped (no overshoot). Below 1.0 overshoots and
/// settles with a bounce; lower = bouncier.
/// response: seconds to reach the target. Not a fixed duration — the spring's
/// settle time emerges from damping + response together.
class AppleSpring {
  final double damping;
  final double response;
  final double mass;

  const AppleSpring({
    required this.damping,
    required this.response,
    this.mass = 1.0,
  });

  /// Default UI motion: reposition, layout changes. No overshoot.
  static const AppleSpring standard = AppleSpring(damping: 1.0, response: 0.4);

  /// Snappy, low-latency feedback for direct presses (button/card scale).
  static const AppleSpring snappy = AppleSpring(damping: 1.0, response: 0.22);

  /// Momentum-carrying motion for gesture-released / flicked elements.
  static const AppleSpring momentum = AppleSpring(damping: 0.8, response: 0.4);

  /// Sheets and drawers entering/leaving.
  static const AppleSpring drawer = AppleSpring(damping: 0.8, response: 0.3);

  /// Rotation / icon state changes (chevrons, toggles).
  static const AppleSpring rotation = AppleSpring(damping: 0.8, response: 0.4);

  SpringDescription get description {
    final stiffness = math.pow(2 * math.pi / response, 2) * mass;
    final dampingCoefficient = 4 * math.pi * damping * mass / response;
    return SpringDescription(
      mass: mass,
      stiffness: stiffness.toDouble(),
      damping: dampingCoefficient,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppleSpring &&
          other.damping == damping &&
          other.response == response &&
          other.mass == mass);

  @override
  int get hashCode => Object.hash(damping, response, mass);
}
