import 'package:flutter/material.dart';

/// Central place to read platform accessibility motion signals.
class MotionQuery {
  const MotionQuery._();

  /// True when the user has "Reduce Motion" enabled at the OS level.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
