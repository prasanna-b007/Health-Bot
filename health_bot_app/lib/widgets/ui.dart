import 'package:flutter/material.dart';

import '../motion/pressable.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// The shared pieces every screen is built from.
///
/// There are deliberately few of them. One card, one heading, one pill, one
/// top bar — so a row on the home screen and the same row in history are the
/// same row, and a change here is a change everywhere.

// ═══════════════════════════════════════════════════════════════════════════
// Surfaces
// ═══════════════════════════════════════════════════════════════════════════

/// The card.
///
/// White on the paper canvas, one hairline border, a whisper of shadow.
/// Passing an [accent] tints the border and lays a pale wash of that colour
/// into the fill — which is how a card says it is selected, live, or urgent,
/// without changing its shape or its weight.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space20),
    this.accent,
    this.onTap,
    this.radius = AppTheme.radiusLg,
    this.fill,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Tints the border and the fill. Null is a plain resting card.
  final Color? accent;

  final VoidCallback? onTap;
  final double radius;
  final Color? fill;

  /// False drops the shadow — for a card nested inside another surface, where
  /// a second shadow would only muddy the edge.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final background =
        fill ??
        (accent == null ? AppColors.surface : AppColors.wash(accent!, 0.05));

    // A card given its own fill borders in that same colour. Otherwise the
    // pale default hairline draws a visible light ring around a dark card —
    // which is what the one filled card in the app, the home screen's primary
    // action, would otherwise get.
    final Border border = accent != null
        ? AppTheme.accentBorder(accent!, alpha: 0.35)
        : fill != null
        ? Border.all(color: fill!, width: AppColors.strokeWidth)
        : AppTheme.hairline;

    final card = AnimatedContainer(
      duration: AppTheme.quick,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: elevated ? AppTheme.cardShadow : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;
    return Pressable(onTap: onTap, pressedScale: 0.99, child: card);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Headings and rows
// ═══════════════════════════════════════════════════════════════════════════

/// The heading above a group of cards, with room for one action on the right.
///
/// Plain sentence case. A heading's job is to name the group, and it does that
/// at 13px in a heavier weight — it does not need tracked-out capitals and a
/// rule running to the margin to be found.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AppText.label.copyWith(color: color ?? AppColors.textMuted),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A quiet text link, for the one optional action beside a [SectionHeading].
class TextAction extends StatelessWidget {
  const TextAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.none,
      pressedScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: AppText.label.copyWith(color: AppColors.signal),
        ),
      ),
    );
  }
}

/// One fact per line: label on the left, value on the right.
///
/// A short value sits on the label's line, right-aligned, so a column of them
/// lines up and can be compared. A long one — "Symptoms" is often a whole
/// sentence — drops below the label and reads left to right instead, because
/// a right-aligned ragged-left paragraph is hard work for no benefit.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Roughly where a value stops being a reading and starts being a sentence.
  static const _stackAbove = 32;

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppText.value.copyWith(color: valueColor);

    if (value.length > _stackAbove) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.bodySm),
            const SizedBox(height: 2),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: AppText.bodySm)),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Small parts
// ═══════════════════════════════════════════════════════════════════════════

/// A small status chip: a risk band, a confidence level, a matched symptom.
///
/// [filled] gives it a tint of its own colour; unfilled is a plain outline for
/// a list of chips where no single one is the point.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.color = AppColors.signal,
    this.filled = true,
    this.icon,
  });

  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: icon == null ? 10 : 8,
        right: 10,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: filled ? AppColors.wash(color, 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: color.withValues(alpha: filled ? 0.22 : 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(text, style: AppText.tag.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// A small solid dot, used where a word would be one word too many — beside
/// "Emergency help", in front of a status line.
class Dot extends StatelessWidget {
  const Dot({super.key, this.color = AppColors.signal, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// A thin progress track. One shape for every "how far along" in the app, so
/// interview progress and profile completeness read the same way.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    this.color = AppColors.signal,
    this.height = 4,
  });

  /// 0..1.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(color: AppColors.surfaceHigh),
              AnimatedContainer(
                duration: AppTheme.medium,
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * value.clamp(0.0, 1.0),
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chrome
// ═══════════════════════════════════════════════════════════════════════════

/// The top bar: the screen's name and a way back, on the page background with
/// a hairline underneath. No raised bar, no tint, no shadow.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.showDivider = true,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showDivider;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              )
            : null,
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: leading == null ? AppTheme.gutter : 4,
        iconTheme: const IconThemeData(color: AppColors.text),
        leading: leading,
        actions: actions,
        title: title == null ? null : Text(title!, style: AppText.h2),
      ),
    );
  }
}

/// A plain icon button sized for a thumb. No chip, no circle behind it — a
/// back arrow does not need a container to be recognised.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.text,
    this.tooltip,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;

  /// What a screen reader announces. Falls back to [tooltip].
  ///
  /// An icon carries no text, so without one of these the button is announced
  /// as an unlabelled control — which, for the back arrow and the share
  /// action, means the only way out of a screen is unlabelled.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget button = Semantics(
      label: semanticLabel ?? tooltip,
      child: Pressable(
        onTap: onTap,
        haptic: PressHaptic.none,
        pressedScale: 0.88,
        // 48x48, not 44: iOS asks for 44 and Android for 48, and the larger
        // of the two is the one to build. Flutter's androidTapTargetGuideline
        // fails at 44, which is what this used to be.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The footer holding a screen's primary action. Sits on the page background
/// with a hairline above, so scrolling content passes under a defined edge
/// instead of colliding with the button.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        AppTheme.space16,
        AppTheme.gutter,
        AppTheme.space8,
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
