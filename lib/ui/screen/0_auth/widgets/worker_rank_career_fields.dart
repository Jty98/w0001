import 'package:flutter/material.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 역할(`worker_rank`)·경력(`career`) 입력.
class WorkerRankCareerFields extends StatefulWidget {
  const WorkerRankCareerFields({
    super.key,
    this.initialRank = '',
    this.initialCareer = '',
    this.compact = false,
    this.onChanged,
  });

  final String initialRank;
  final String initialCareer;
  final bool compact;
  final VoidCallback? onChanged;

  @override
  State<WorkerRankCareerFields> createState() => WorkerRankCareerFieldsState();
}

class WorkerRankCareerFieldsState extends State<WorkerRankCareerFields> {
  late String _rank;
  late final TextEditingController _career;

  @override
  void initState() {
    super.initState();
    _rank = _normalizeRank(widget.initialRank);
    _career = TextEditingController(text: widget.initialCareer);
    _career.addListener(_notify);
  }

  @override
  void didUpdateWidget(WorkerRankCareerFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRank != widget.initialRank) {
      _rank = _normalizeRank(widget.initialRank);
    }
    if (oldWidget.initialCareer != widget.initialCareer &&
        _career.text != widget.initialCareer) {
      _career.text = widget.initialCareer;
    }
  }

  @override
  void dispose() {
    _career.removeListener(_notify);
    _career.dispose();
    super.dispose();
  }

  String get workerRank => _rank;

  String get career => _career.text.trim();

  void _notify() => widget.onChanged?.call();

  String _normalizeRank(String raw) {
    final t = raw.trim();
    if (t.isEmpty || kWorkerRankOptions.contains(t)) return t;
    return '';
  }

  WorkerProfileRead mergeInto(WorkerProfileRead base) {
    return WorkerProfileRead(
      uid: base.uid,
      primarySpecialty: base.primarySpecialty,
      specialties: base.specialties,
      workerRank: _rank,
      career: career,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final gap = context.rsi(widget.compact ? 10 : 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '현장 역할',
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: context.rsi(6)),
        DropdownButtonFormField<String>(
          value: _rank.isEmpty ? '' : _rank,
          decoration: InputDecoration(
            hintText: '선택 안 함',
            isDense: widget.compact,
            border: const OutlineInputBorder(),
            contentPadding: widget.compact
                ? EdgeInsets.symmetric(
                    horizontal: context.rsi(12),
                    vertical: context.rsi(10),
                  )
                : null,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('선택 안 함')),
            for (final r in kWorkerRankOptions)
              DropdownMenuItem(value: r, child: Text(r)),
          ],
          onChanged: (v) {
            setState(() => _rank = v ?? '');
            _notify();
          },
        ),
        SizedBox(height: gap),
        Text(
          '경력',
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: context.rsi(6)),
        TextField(
          controller: _career,
          maxLength: 2000,
          maxLines: widget.compact ? 3 : 4,
          scrollPadding: keyboardScrollPadding(context, extra: 96),
          style: tt.bodyMedium,
          decoration: InputDecoration(
            hintText: '예: 인테리어 현장 5년',
            isDense: widget.compact,
            border: const OutlineInputBorder(),
            counterStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            alignLabelWithHint: true,
            contentPadding: widget.compact
                ? EdgeInsets.symmetric(
                    horizontal: context.rsi(12),
                    vertical: context.rsi(10),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
