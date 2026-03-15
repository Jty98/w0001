import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      width: witdh ?? 230,
      height: height ?? 45,
      child: TextField(
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        readOnly: readOnly,
        controller: tController,
        decoration: InputDecoration(
          prefixText: prefixText,
          labelStyle: const TextStyle(fontSize: 14),
          hintStyle: const TextStyle(fontSize: 14),
          border: border ??
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelText: labelText,
          suffixText: isPrice ? '원' : '',
        ),
        textAlign: isPrice ? TextAlign.right : TextAlign.left,
        textInputAction: TextInputAction.done,
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
