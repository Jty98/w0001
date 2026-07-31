import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 주민등록번호 — 앞 6자리·뒤 7자리 분리 입력(뒷자리만 마스킹).
class ResidentRegistrationSplitField extends StatefulWidget {
  const ResidentRegistrationSplitField({
    super.key,
    required this.frontController,
    required this.backController,
    required this.onChanged,
    this.frontFocusNode,
    this.backFocusNode,
    this.labelText = '주민등록번호',
    this.enabled = true,
    this.showClearButton = false,
    this.errorText,
    this.height,
    this.viewModeTrailing,
  });

  final TextEditingController frontController;
  final TextEditingController backController;
  final FocusNode? frontFocusNode;
  final FocusNode? backFocusNode;
  final ValueChanged<String> onChanged;
  final String labelText;
  final bool enabled;
  final bool showClearButton;
  final String? errorText;
  final double? height;
  final Widget? viewModeTrailing;

  @override
  State<ResidentRegistrationSplitField> createState() =>
      _ResidentRegistrationSplitFieldState();
}

class _ResidentRegistrationSplitFieldState
    extends State<ResidentRegistrationSplitField> {
  var _obscureBack = true;

  static const _obscureChar = '•';

  String get _combined => joinResidentRegistrationParts(
        widget.frontController.text,
        widget.backController.text,
      );

  bool get _isMasked => isMaskedResidentRegistration(_combined);

  TextStyle _digitStyle(BuildContext context) {
    return AppInputStyles.fieldText(
      context,
      designFontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.15,
    ).copyWith(
      fontFamily: 'monospace',
      letterSpacing: 0,
    );
  }

  void _clearAll() {
    widget.frontController.clear();
    widget.backController.clear();
    widget.onChanged('');
  }

  void _clearMaskIfNeeded() {
    if (!_isMasked) return;
    widget.frontController.clear();
    widget.backController.clear();
  }

  void _onFrontChanged(String value) {
    final digits = normalizeResidentRegistrationNumber(value);
    final limited = digits.length > 6 ? digits.substring(0, 6) : digits;
    if (limited != value) {
      widget.frontController.value = TextEditingValue(
        text: limited,
        selection: TextSelection.collapsed(offset: limited.length),
      );
    }
    if (limited.length == 6 && widget.enabled) {
      widget.backFocusNode?.requestFocus();
    }
    widget.onChanged(_combined);
    setState(() {});
  }

  void _onBackChanged(String value) {
    final digits = normalizeResidentRegistrationNumber(value);
    final limited = digits.length > 7 ? digits.substring(0, 7) : digits;
    if (limited != value) {
      widget.backController.value = TextEditingValue(
        text: limited,
        selection: TextSelection.collapsed(offset: limited.length),
      );
    }
    widget.onChanged(_combined);
    setState(() {});
  }

  InputDecoration _partDecoration(
    BuildContext context, {
    required String hintText,
    required bool hasError,
  }) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.rs(10));
    final errorBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: cs.error, width: 1.5),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: context.rsi(11),
        fontWeight: FontWeight.w500,
      ),
      counterText: '',
      enabledBorder: hasError ? errorBorder : null,
      focusedBorder: hasError ? errorBorder : null,
      border: OutlineInputBorder(borderRadius: radius),
      contentPadding: ResponsiveLayout.symmetric(
        context,
        horizontal: 8,
        vertical: 10,
      ),
      isDense: true,
    );
  }

  bool get _obscureBackField {
    // 보기 모드 — 컨트롤러 텍스트(마스킹 * 또는 reveal 숫자)를 그대로 표시
    if (!widget.enabled) return false;
    if (_isMasked) return false;
    return _obscureBack;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fieldHeight = widget.height ?? context.rsi(54);
    final hasError =
        widget.errorText != null && widget.errorText!.trim().isNotEmpty;
    final digitStyle = _digitStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.labelText,
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: context.rsi(13),
          ),
        ),
        SizedBox(height: context.rsi(6)),
        SizedBox(
          height: fieldHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 6,
                child: AppTextField(
                  controller: widget.frontController,
                  focusNode: widget.frontFocusNode,
                  enabled: widget.enabled,
                  readOnly: !widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: digitStyle,
                  scrollPadding: keyboardScrollPadding(context),
                  inputFormatters: widget.enabled && !_isMasked
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  onTap:
                      widget.enabled && _isMasked ? _clearMaskIfNeeded : null,
                  onChanged: _onFrontChanged,
                  decoration: _partDecoration(
                    context,
                    hintText: '앞 6자리',
                    hasError: hasError,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                child: Text(
                  '-',
                  style: digitStyle.copyWith(
                    fontSize: context.rsi(16),
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    height: 1,
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: AppTextField(
                  controller: widget.backController,
                  focusNode: widget.backFocusNode,
                  enabled: widget.enabled,
                  readOnly: !widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  obscureText: _obscureBackField,
                  obscuringCharacter: _obscureChar,
                  style: digitStyle,
                  scrollPadding: keyboardScrollPadding(context),
                  inputFormatters: widget.enabled && !_isMasked
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  onTap:
                      widget.enabled && _isMasked ? _clearMaskIfNeeded : null,
                  onChanged: _onBackChanged,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  decoration: _partDecoration(
                    context,
                    hintText: '뒤 7자리',
                    hasError: hasError,
                  ),
                ),
              ),
              if (widget.enabled) ...[
                SizedBox(
                  width: context.rsi(
                    widget.showClearButton && _combined.isNotEmpty && !_isMasked
                        ? 72
                        : 36,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.showClearButton && _combined.isNotEmpty)
                        IconButton(
                          tooltip: '전체 지우기',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: context.rsi(32),
                            height: context.rsi(32),
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          visualDensity: VisualDensity.compact,
                          iconSize: context.rsi(18),
                          onPressed: _clearAll,
                          icon: const Icon(Icons.close),
                        ),
                      if (!_isMasked)
                        IconButton(
                          tooltip: _obscureBack ? '뒷자리 표시' : '뒷자리 숨기기',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: context.rsi(32),
                            height: context.rsi(32),
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          visualDensity: VisualDensity.compact,
                          iconSize: context.rsi(18),
                          onPressed: () =>
                              setState(() => _obscureBack = !_obscureBack),
                          icon: Icon(
                            _obscureBack
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                    ],
                  ),
                ),
              ] else if (widget.viewModeTrailing != null) ...[
                SizedBox(width: context.rsi(4)),
                widget.viewModeTrailing!,
              ],
            ],
          ),
        ),
        if (hasError) ...[
          SizedBox(height: context.rsi(6)),
          Text(
            widget.errorText!,
            style: tt.bodySmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w600,
              fontSize: context.rsi(12),
            ),
          ),
        ],
      ],
    );
  }
}
