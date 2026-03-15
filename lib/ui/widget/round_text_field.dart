import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/ui/screen/4_human/human_screen.dart';

class RoundTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final double? height;
  final ValueChanged onChanged;

  const RoundTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.maxLines,
    this.maxLength,
    this.keyboardType,
    this.height,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
      height: height ?? 66,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13), // 13자리 숫자만 입력 가능
                NumberFormatter(),
              ]
            : [],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
