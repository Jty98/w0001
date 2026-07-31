import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 천 단위 콤마 포맷터
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 숫자만 추출
    final numericValue = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (numericValue.isEmpty) {
      return const TextEditingValue();
    }

    // 천 단위 콤마 추가
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedValue = numericValue.replaceAllMapped(
      formatter,
      (match) => '${match[1]},',
    );

    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}

/// 인력 상세 정보 수정 시트
class WorkerDetailsSheet extends StatefulWidget {
  const WorkerDetailsSheet({
    super.key,
    required this.human,
    required this.currentRole,
    required this.currentWage,
    required this.onSave,
  });

  final HumanModel human;
  final String currentRole;
  final int currentWage;
  final Function(String role, int wage) onSave;

  @override
  State<WorkerDetailsSheet> createState() => _WorkerDetailsSheetState();
}

class _WorkerDetailsSheetState extends State<WorkerDetailsSheet> {
  late final TextEditingController _roleController;
  late final TextEditingController _wageController;

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController(text: widget.currentRole);
    // 일당을 천 단위 콤마 포맷으로 초기화
    _wageController =
        TextEditingController(text: _formatCurrency(widget.currentWage));
  }

  /// 통화 포맷팅 (천 단위 콤마)
  String _formatCurrency(int amount) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return amount
        .toString()
        .replaceAllMapped(formatter, (match) => '${match[1]},');
  }

  @override
  void dispose() {
    _roleController.dispose();
    _wageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              CircleAvatar(
                radius: context.rs(24),
                backgroundColor: cs.primaryContainer,
                child: Text(
                  widget.human.hname[0],
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.human.hname,
                      style:
                          tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '역할 및 일당 설정',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: context.rsi(24)),

          // 역할 입력
          TextField(
            controller: _roleController,
            decoration: InputDecoration(
              labelText: '작업 역할',
              hintText: '예: 타일공사, 목공사',
              prefixIcon: const Icon(Icons.work_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
            ),
          ),

          SizedBox(height: context.rsi(16)),

          // 일당 입력
          TextField(
            controller: _wageController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: '일당',
              hintText: '예: 200,000',
              prefixIcon: const Icon(Icons.attach_money),
              suffixText: '원',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
            ),
          ),

          SizedBox(height: context.rsi(24)),

          // 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(context.rs(48)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    final role = _roleController.text.trim();
                    // 콤마 제거 후 정수 변환
                    final wageText =
                        _wageController.text.trim().replaceAll(',', '');
                    final wage = int.tryParse(wageText);

                    if (role.isNotEmpty && wage != null && wage > 0) {
                      widget.onSave(role, wage);
                      Navigator.pop(context);
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(context.rs(48)),
                  ),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
