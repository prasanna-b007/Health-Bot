import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apple_spring.dart';
import 'spring_value.dart';

enum PressHaptic { none, light, medium, selection }

/// Wraps [child] with instant press-down feedback (scale, spring-driven,
/// interruptible) and commits [onTap] on release — never waits for the
/// gesture to fully resolve before showing something happened.
///
/// It also declares the button role to the accessibility tree. A bare
/// [GestureDetector] exposes a tap action but no role, so every tappable
/// surface in this app — which is all of them, since AppButton, AppCard,
/// AppIconButton and the answer chips all build on Pressable — was read out
/// by TalkBack and VoiceOver as plain text. Someone using a screen reader had
/// no way to tell the difference between a label and the button that
/// dismisses an emergency screen.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final PressHaptic haptic;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.haptic = PressHaptic.light,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case PressHaptic.none:
        break;
      case PressHaptic.light:
        HapticFeedback.lightImpact();
        break;
      case PressHaptic.medium:
        HapticFeedback.mediumImpact();
        break;
      case PressHaptic.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTap: enabled
            ? () {
                _fireHaptic();
                widget.onTap!();
              }
            : null,
        child: SpringBuilder(
          value: _pressed ? widget.pressedScale : 1.0,
          spring: AppleSpring.snappy,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
