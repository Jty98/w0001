import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

class AddTextField extends StatelessWidget {
  final TextEditingController tController;
  final bool readOnly;
  final String labelText;
  final TextInputType? keyboardType;
  final bool isPrice;
  final double? height;
  final String? prefixText;
  final FocusNode? focusNode;
  final InputBorder? border;
  final ValueChanged? onChanged;
  final ValueChanged? onSubmitted;
  final double? witdh;
  final int minLines;
  final int maxLines;

  /// 금액 추가 탭 등 좁은 칸 — 입력·라벨 글자 크기 축소.
  final bool compact;

  /// [Row] 안에 나란히 둘 때 하단 여백 제거.
  final bool omitBottomMargin;

  const AddTextField({
    super.key,
    this.witdh,
    required this.tController,
    required this.labelText,
    required this.isPrice,
    this.border,
    this.keyboardType,
    this.prefixText,
    required this.readOnly,
    this.focusNode,
    this.height,
    this.onSubmitted,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.compact = false,
    this.omitBottomMargin = false,
  });

  bool get _isMultiline => minLines > 1 || maxLines > 1;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fieldH = height ?? context.rs(compact ? 46 : 45);
    final minMultilineH = height ?? context.rs(compact ? 48 : 52);
    final labelStyle = compact ? tt.labelMedium : tt.bodyMedium;
    final inputStyle = compact
        ? AppInputStyles.fieldText(
            context,
            base: tt.bodySmall,
            designFontSize: 13,
            height: isPrice ? 1.1 : 1.25,
            fontWeight: isPrice ? FontWeight.w600 : FontWeight.w500,
          )
        : AppInputStyles.fieldText(
            context,
            height: _isMultiline ? 1.35 : null,
          );
    final hPad = compact ? 10.0 : 12.0;
    const compactVPad = 10.0;

    return Container(
      margin: EdgeInsets.only(
        bottom: (compact && omitBottomMargin) ? 0 : context.rs(compact ? 4 : 7),
      ),
      width: witdh ?? context.rs(230),
      height: _isMultiline ? null : fieldH,
      constraints:
          _isMultiline ? BoxConstraints(minHeight: minMultilineH) : null,
      child: AppTextField(
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        scrollPadding: keyboardScrollPadding(context, extra: 120),
        readOnly: readOnly,
        controller: tController,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixText: prefixText,
          labelStyle: labelStyle,
          hintStyle: labelStyle,
          isDense: compact,
          isCollapsed: compact && !_isMultiline,
          alignLabelWithHint: _isMultiline,
          contentPadding: _isMultiline
              ? ResponsiveLayout.symmetric(
                  context,
                  horizontal: hPad,
                  vertical: 12,
                )
              : EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: compact ? compactVPad : 10,
                ),
          border: border ??
              OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(10)),
              ),
          labelText: labelText,
          suffixText: isPrice ? '원' : '',
          suffixStyle: compact
              ? tt.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        style: inputStyle,
        textAlign: isPrice ? TextAlign.right : TextAlign.left,
        textInputAction:
            _isMultiline ? TextInputAction.newline : TextInputAction.done,
        keyboardType: keyboardType,
        inputFormatters: isPrice
            ? [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyTextInputFormatter.currency(
                  decimalDigits: 0,
                  symbol: '',
                ),
                LengthLimitingTextInputFormatter(13),
              ]
            : [],
      ),
    );
  }
}
