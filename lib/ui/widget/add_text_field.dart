import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/responsive_layout.dart';

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
  });

  bool get _isMultiline => minLines > 1 || maxLines > 1;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fieldH = height ?? context.rs(45);
    final minMultilineH = height ?? context.rs(52);
    return Container(
      margin: EdgeInsets.only(bottom: context.rs(7)),
      width: witdh ?? context.rs(230),
      height: _isMultiline ? null : fieldH,
      constraints: _isMultiline
          ? BoxConstraints(minHeight: minMultilineH)
          : null,
      child: TextField(
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
          labelStyle: tt.bodyMedium,
          hintStyle: tt.bodyMedium,
          alignLabelWithHint: _isMultiline,
          contentPadding: _isMultiline
              ? ResponsiveLayout.symmetric(
                  context,
                  horizontal: 12,
                  vertical: 12,
                )
              : ResponsiveLayout.symmetric(
                  context,
                  horizontal: 12,
                  vertical: 10,
                ),
          border: border ??
              OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(10)),
              ),
          labelText: labelText,
          suffixText: isPrice ? '원' : '',
        ),
        style: tt.bodyMedium?.copyWith(
          height: _isMultiline ? 1.35 : null,
        ),
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
