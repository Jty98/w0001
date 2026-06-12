import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_number_formatter.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/responsive_layout.dart';

class RoundTextField extends StatelessWidget {
  static const double _suffixActionSize = 36;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final double? height;
  final bool obscureText;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final String? helperText;
  final TextStyle? helperStyle;
  final bool showClearButton;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// [TextField.scrollPadding] 하단 추가 여백.
  final double scrollPaddingExtra;

  /// false면 빨간 테두리만 표시하고 오류 문구는 [errorText]로 외부 배치.
  final bool showErrorMessageBelow;

  /// [suffixIcon]이 텍스트 버튼 등 넓을 때 슬롯 너비(기본 36).
  final double? suffixTrailingWidth;

  const RoundTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.maxLines,
    this.maxLength,
    this.keyboardType,
    this.height,
    this.obscureText = false,
    this.suffixIcon,
    this.autofillHints,
    this.errorText,
    this.helperText,
    this.helperStyle,
    this.showClearButton = false,
    this.inputFormatters,
    this.scrollPaddingExtra = 96,
    this.showErrorMessageBelow = true,
    this.suffixTrailingWidth,
    this.enabled = true,
    required this.onChanged,
  });

  Widget _suffixActionSlot(
    BuildContext context,
    Widget child, {
    double? width,
  }) {
    final w = width ?? context.rs(_suffixActionSize);
    final h = context.rs(_suffixActionSize);
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: OverflowBox(
          maxHeight: h,
          child: Center(child: child),
        ),
      ),
    );
  }

  List<TextInputFormatter> _formatters() {
    if (inputFormatters != null) return inputFormatters!;
    if (keyboardType == TextInputType.number) {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(13),
        HumanNumberFormatter(),
      ];
    }
    return const [];
  }

  double _suffixSlotWidth(BuildContext context) {
    final slot = context.rs(_suffixActionSize);
    final clearW = showClearButton ? slot : 0.0;
    final trailingW = suffixIcon != null
        ? (suffixTrailingWidth ?? slot)
        : 0.0;
    return clearW + trailingW;
  }

  Widget? _suffixWidget() {
    if (!showClearButton && suffixIcon == null) return null;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final showClear = showClearButton && controller.text.isNotEmpty;
        final slotW = _suffixSlotWidth(context);
        if (slotW <= 0) return const SizedBox.shrink();

        return SizedBox(
          width: slotW,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showClearButton)
                _suffixActionSlot(
                  context,
                  Opacity(
                    opacity: showClear ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !showClear,
                      child: IconButton(
                        tooltip: '전체 지우기',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: BoxConstraints(
                          minWidth: context.rs(_suffixActionSize),
                          maxWidth: context.rs(_suffixActionSize),
                          minHeight: context.rs(_suffixActionSize),
                          maxHeight: context.rs(_suffixActionSize),
                        ),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                        icon: Icon(Icons.close, size: context.rsi(20)),
                      ),
                    ),
                  ),
                ),
              if (suffixIcon != null)
                _suffixActionSlot(
                  context,
                  suffixIcon!,
                  width: suffixTrailingWidth,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldHeight = height ?? context.rs(66);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasError = errorText != null && errorText!.trim().isNotEmpty;
    final radius = BorderRadius.circular(context.rs(10));
    final errorBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: cs.error, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: fieldHeight,
          child: TextField(
            scrollPadding: keyboardScrollPadding(
              context,
              extra: scrollPaddingExtra,
            ),
            focusNode: focusNode,
            controller: controller,
            obscureText: obscureText,
            autofillHints: autofillHints,
            maxLines: obscureText ? 1 : maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: _formatters(),
            onChanged: onChanged,
            readOnly: !enabled,
            decoration: InputDecoration(
              hintText: hintText,
              labelText: labelText,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: _suffixWidget(),
              helperText: helperText,
              helperStyle: helperStyle,
              counterText: '',
              constraints: BoxConstraints.tightFor(height: fieldHeight),
              enabledBorder: hasError ? errorBorder : null,
              focusedBorder: hasError ? errorBorder : null,
              border: OutlineInputBorder(borderRadius: radius),
              contentPadding: ResponsiveLayout.symmetric(
                context,
                horizontal: 14,
                vertical: 14,
              ),
            ),
            style: tt.bodyMedium,
          ),
        ),
        if (hasError && showErrorMessageBelow)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(4),
              context.rsi(4),
              context.rsi(4),
              0,
            ),
            child: Text(
              errorText!,
              style: tt.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
      ],
    );
  }
}
