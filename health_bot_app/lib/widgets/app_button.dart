import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/apple_spring.dart';
import '../motion/pressable.dart';
import '../motion/spring_value.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

enum AppButtonVariant {
  /// The one action the screen exists for. Solid, white text.
  primary,

  /// Everything else. A white surface with a border — present, not competing.
  secondary,

  /// A quiet action that should not look like a target at all.
  ghost,

  /// Emergency only.
  danger,
}

/// The app's button.
///
/// Flat fill, one radius, no shadow. The only feedback on press is a small
/// scale and a shade of the fill — spring-driven and interruptible, so a fast
/// double tap or a drag-off never leaves it stuck mid-state.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.haptic = PressHaptic.light,
    this.loading = false,
    this.accent,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final bool fullWidth;
  final PressHaptic haptic;
  final bool loading;

  /// Overrides the variant's colour, where a button should carry the meaning
  /// of the thing it acts on — a risk level, an answer.
  final Color? accent;

  final bool compact;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
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
      case PressHaptic.medium:
        HapticFeedback.mediumImpact();
      case PressHaptic.selection:
        HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final accent =
        widget.accent ??
        switch (widget.variant) {
          AppButtonVariant.danger => AppColors.ember,
          _ => AppColors.signal,
        };

    final solid =
        widget.variant == AppButtonVariant.primary ||
        widget.variant == AppButtonVariant.danger;
    final ghost = widget.variant == AppButtonVariant.ghost;

    final Color fill = ghost
        ? Colors.transparent
        : solid
        ? accent
        : AppColors.surface;
    final Color foreground = solid
        ? AppColors.textInverse
        : ghost
        ? AppColors.textMuted
        : AppColors.text;

    final radius = BorderRadius.circular(
      widget.compact ? AppTheme.radiusSm : AppTheme.radiusMd,
    );

    // One clean accessibility node for the whole control: the role, the
    // enabled state and the label together. Without this the button was
    // announced as bare text, and a disabled one was indistinguishable from
    // an active one by anything but the opacity.
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      label: widget.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.42 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: disabled ? null : (_) => _setPressed(true),
          onTapCancel: disabled ? null : () => _setPressed(false),
          onTapUp: disabled ? null : (_) => _setPressed(false),
          onTap: disabled
              ? null
              : () {
                  _fireHaptic();
                  widget.onPressed!();
                },
          child: SpringBuilder(
            value: _pressed && !disabled ? 1 : 0,
            spring: AppleSpring.snappy,
            builder: (context, t, child) => Transform.scale(
              scale: 1 - 0.015 * t.clamp(0.0, 1.0),
              child: child,
            ),
            child: AnimatedContainer(
              duration: AppTheme.quick,
              width: widget.fullWidth ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                vertical: widget.compact ? 10 : 15,
                horizontal: widget.compact
                    ? AppTheme.space16
                    : AppTheme.space24,
              ),
              decoration: BoxDecoration(
                // Pressing darkens a solid fill and tints a light one. On paper
                // that is the whole story — there is no bloom to brighten.
                color: _pressed && !disabled
                    ? (solid
                          ? Color.alphaBlend(
                              AppColors.text.withValues(alpha: 0.16),
                              fill,
                            )
                          : AppColors.surfaceRaised)
                    : fill,
                borderRadius: radius,
                border: solid || ghost
                    ? null
                    : Border.all(color: AppColors.strokeStrong, width: 1),
              ),
              child: _content(foreground, accent, solid),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Color foreground, Color accent, bool solid) {
    if (widget.loading) {
      return SizedBox(
        height: widget.compact ? 17 : 21,
        child: Center(
          child: SizedBox(
            width: widget.compact ? 16 : 18,
            height: widget.compact ? 16 : 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: solid ? AppColors.textInverse : accent,
            ),
          ),
        ),
      );
    }

    // On a light secondary button the icon takes the accent so the button
    // still says which thing it belongs to; the label stays plain ink.
    final iconColor = solid ? AppColors.textInverse : accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.compact ? 15 : 17, color: iconColor),
          const SizedBox(width: AppTheme.space8),
        ],
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: widget.compact ? 13.5 : 15,
              height: 1.2,
            ),
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: AppTheme.space8),
          Icon(
            widget.trailingIcon,
            size: widget.compact ? 15 : 17,
            color: iconColor,
          ),
        ],
      ],
    );
  }
}
