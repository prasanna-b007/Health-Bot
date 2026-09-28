import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/pressable.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// The app's text field.
///
/// A field is the page colour set into a white card — slightly darker than
/// what surrounds it, so it reads as somewhere to put something rather than
/// as another panel. Focus thickens the border to the accent colour. That is
/// all: no ring, no shadow, no fill change.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.textAlign = TextAlign.start,
    this.style,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final TextAlign textAlign;
  final TextStyle? style;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _owned;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_owned ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _focused != _node.hasFocus) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    // Only the node this widget created is ours to dispose.
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = (widget.errorText ?? '').isNotEmpty;
    // Error outranks focus: a focused field with a problem must show the
    // problem, not the focus ring.
    final edge = hasError
        ? AppColors.ember
        : _focused
        ? AppColors.signal
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: AppTheme.quick,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: edge ?? AppColors.stroke,
              width: edge == null ? 1 : 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space4,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _node,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  textAlign: widget.textAlign,
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: AppColors.signal,
                  cursorWidth: 1.6,
                  style: widget.style ?? AppText.body,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppTheme.space12,
                    ),
                    hintText: widget.hint,
                    hintStyle: (widget.style ?? AppText.body).copyWith(
                      color: AppColors.textFaint,
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: AppTheme.space8),
                widget.suffix!,
              ],
            ],
          ),
        ),
        if (hasError || (widget.helperText ?? '').isNotEmpty) ...[
          const SizedBox(height: AppTheme.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: hasError ? AppColors.ember : AppColors.textFaint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasError ? widget.errorText! : widget.helperText!,
                  style: AppText.caption.copyWith(
                    color: hasError ? AppColors.ember : AppColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A single-choice row of options.
///
/// The selected chip is the only one carrying colour: a tint of the accent,
/// its border, and its label. Everything else stays grey. One coloured thing
/// in a row is faster to find than five competing for attention.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.accent = AppColors.signal,
    this.wrap = true,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final Color accent;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final chips = options.map((option) {
      final isSelected = option == selected;
      return Pressable(
        haptic: PressHaptic.selection,
        pressedScale: 0.96,
        onTap: () => onChanged(option),
        child: AnimatedContainer(
          duration: AppTheme.quick,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.wash(accent, 0.10)
                : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.45)
                  : AppColors.stroke,
              width: 1,
            ),
          ),
          child: Text(
            labelOf(option),
            style: AppText.body.copyWith(
              fontSize: 14,
              color: isSelected ? accent : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }).toList();

    if (!wrap) {
      return Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppTheme.space8),
            chips[i],
          ],
        ],
      );
    }
    return Wrap(
      spacing: AppTheme.space8,
      runSpacing: AppTheme.space8,
      children: chips,
    );
  }
}

/// An editable list of short free-text entries — conditions, allergies,
/// medications.
///
/// Entries are added on submit and removed by tapping their own ✕. Duplicates
/// are rejected case-insensitively: "Asthma" and "asthma" listed side by side
/// looks like a bug in something presented as a medical summary.
class TagEditor extends StatefulWidget {
  const TagEditor({
    super.key,
    required this.values,
    required this.onChanged,
    required this.hint,
    this.accent = AppColors.pulse,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String hint;
  final Color accent;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final exists = widget.values.any(
      (v) => v.toLowerCase() == text.toLowerCase(),
    );
    if (!exists) widget.onChanged([...widget.values, text]);
    _controller.clear();
  }

  void _remove(String value) =>
      widget.onChanged(widget.values.where((v) => v != value).toList());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller,
          hint: widget.hint,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _add(),
          suffix: Pressable(
            haptic: PressHaptic.selection,
            onTap: _add,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(Icons.add_rounded, size: 20, color: widget.accent),
            ),
          ),
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space12),
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space8,
            children: widget.values
                .map(
                  (value) => Pressable(
                    haptic: PressHaptic.light,
                    pressedScale: 0.94,
                    onTap: () => _remove(value),
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 8,
                        top: 6,
                        bottom: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.wash(widget.accent, 0.09),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.28),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value,
                            style: AppText.body.copyWith(
                              fontSize: 13.5,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: widget.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
