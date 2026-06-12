import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 가입 — 주민등록번호 입력 섹션.
class WorkerSignupResidentSection extends StatefulWidget {
  const WorkerSignupResidentSection({
    super.key,
    required this.controller,
    required this.onChanged,
    this.labelText = '주민등록번호',
    this.hintText = '000000-0000000',
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String labelText;
  final String hintText;

  @override
  State<WorkerSignupResidentSection> createState() =>
      _WorkerSignupResidentSectionState();
}

class _WorkerSignupResidentSectionState extends State<WorkerSignupResidentSection> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final value = widget.controller.text;
    final formatMsg = value.trim().isEmpty
        ? null
        : residentRegistrationFormatMessage(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: context.rs(26),
              height: context.rs(26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(context.rs(8)),
              ),
              child: Text(
                '3',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            SizedBox(width: context.rsi(10)),
            Text(
              '주민등록번호',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rsi(12)),
        RoundTextField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          labelText: widget.labelText,
          hintText: widget.hintText,
          obscureText: _obscure,
          showClearButton: true,
          errorText: formatMsg,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
            ResidentRegistrationFormatter(),
          ],
          suffixIcon: IconButton(
            tooltip: _obscure ? '번호 표시' : '번호 숨기기',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
          ),
          onChanged: (_) => widget.onChanged(),
        ),
      ],
    );
  }
}
