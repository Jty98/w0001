import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

typedef AddProcessDialogResult = ({
  String name,
  int startIdx,
  int endIdx,
});

/// 공정 이름 수정 다이얼로그
Future<String?> showEditProcessNameDialog(
  BuildContext context,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ctx.rs(16)),
        ),
        title: const Text('공정 이름 수정'),
        content: AppTextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '공정 이름',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ctx.rs(12)),
            ),
            filled: true,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(ctx, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx, name);
              }
            },
            child: const Text('수정'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

/// 공사 기간 — [공정 추가]와 동일하게 시작·종료 드롭다운.
class PlacePeriodDropdownDialog extends StatefulWidget {
  const PlacePeriodDropdownDialog({
    super.key,
    required this.dates,
    required this.dateLabels,
    required this.initialStartIdx,
    required this.initialEndIdx,
    this.savedLine,
  });

  final List<DateTime> dates;
  final List<String> dateLabels;
  final int initialStartIdx;
  final int initialEndIdx;

  /// `yyyy.mm.dd ~ yyyy.mm.dd` (표시만)
  final String? savedLine;

  @override
  State<PlacePeriodDropdownDialog> createState() =>
      _PlacePeriodDropdownDialogState();
}

class _PlacePeriodDropdownDialogState extends State<PlacePeriodDropdownDialog> {
  late int _startIdx;
  late int _endIdx;

  @override
  void initState() {
    super.initState();
    final last = widget.dateLabels.length - 1;
    _startIdx = widget.initialStartIdx.clamp(0, last);
    _endIdx = widget.initialEndIdx.clamp(_startIdx, last);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final last = widget.dateLabels.length - 1;
    if (last < 0) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rs(12)),
        ),
        title: const Text('공사 기간'),
        content: const Text('선택 가능한 날짜가 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(12)),
      ),
      title: Text(
        '공사 기간',
        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: context.rs(420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.savedLine != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.rsi(12)),
                child: Text(
                  '현재 공사 기간: ${widget.savedLine}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '시작일',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: context.rsi(4)),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: _startIdx.clamp(0, last),
                        items: [
                          for (var i = 0; i <= last; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                widget.dateLabels[i],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _startIdx = v;
                            if (_endIdx < _startIdx) _endIdx = _startIdx;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '종료일',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: context.rsi(4)),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: _endIdx.clamp(_startIdx, last),
                        items: [
                          for (var i = _startIdx; i <= last; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                widget.dateLabels[i],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _endIdx = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final s = widget.dates[_startIdx];
            final e = widget.dates[_endIdx];
            Navigator.pop(context, (start: s, end: e));
          },
          child: const Text('적용'),
        ),
      ],
    );
  }
}

/// 공정 추가 — [TextEditingController]를 이 State에서만 생성·폐기.
class AddProcessDialog extends StatefulWidget {
  const AddProcessDialog({super.key, required this.dateLabels});

  final List<String> dateLabels;

  @override
  State<AddProcessDialog> createState() => _AddProcessDialogState();
}

class _AddProcessDialogState extends State<AddProcessDialog> {
  late final TextEditingController _nameCtrl;
  late int _startIdx;
  late int _endIdx;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    final last = widget.dateLabels.length - 1;
    _startIdx = 0;
    _endIdx = last >= 3 ? 3 : last;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final last = widget.dateLabels.length - 1;
    if (last < 0) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rs(20)),
        ),
        title: const Text('공정 추가'),
        content: const Text('표시할 날짜가 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(20)),
      ),
      title: const Text('공정 추가'),
      content: SizedBox(
        width: context.rs(420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: '공정 이름',
                  hintText: '예: 전기, 타일, 목공',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rs(12)),
                  ),
                  filled: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: context.rsi(14)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '시작일',
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: context.rsi(4)),
                        DropdownButton<int>(
                          isExpanded: true,
                          value: _startIdx.clamp(0, last),
                          items: [
                            for (var i = 0; i <= last; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  widget.dateLabels[i],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _startIdx = v;
                              if (_endIdx < _startIdx) _endIdx = _startIdx;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '종료일',
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: context.rsi(4)),
                        DropdownButton<int>(
                          isExpanded: true,
                          value: _endIdx.clamp(_startIdx, last),
                          items: [
                            for (var i = _startIdx; i <= last; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  widget.dateLabels[i],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _endIdx = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              (
                name: name,
                startIdx: _startIdx,
                endIdx: _endIdx,
              ),
            );
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
