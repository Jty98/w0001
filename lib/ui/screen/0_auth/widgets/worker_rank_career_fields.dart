import 'package:flutter/material.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/ui/screen/0_auth/widgets/career_input_section.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 역할(`worker_rank`)·경력(`career`) 입력.
class WorkerRankCareerFields extends StatefulWidget {
  const WorkerRankCareerFields({
    super.key,
    this.initialRank = '',
    this.initialCareer = '',
    this.compact = false,
    this.onChanged,
    this.rankEditable = true,
    this.careerEditable = true,
    this.allowStartYearMode = true,
  });

  final String initialRank;
  final String initialCareer;
  final bool compact;
  final VoidCallback? onChanged;
  final bool rankEditable;
  final bool careerEditable;
  final bool allowStartYearMode;

  @override
  State<WorkerRankCareerFields> createState() => WorkerRankCareerFieldsState();
}

class WorkerRankCareerFieldsState extends State<WorkerRankCareerFields> {
  late String _rank;
  late String _career;

  @override
  void initState() {
    super.initState();
    _rank = _normalizeRank(widget.initialRank);
    _career = widget.initialCareer;
  }

  @override
  void didUpdateWidget(WorkerRankCareerFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRank != widget.initialRank) {
      _rank = _normalizeRank(widget.initialRank);
    }
    if (oldWidget.initialCareer != widget.initialCareer) {
      _career = widget.initialCareer;
    }
  }

  String get workerRank => _rank;

  String get career => _career;

  void _notify() => widget.onChanged?.call();

  String _normalizeRank(String raw) {
    final t = raw.trim();
    if (t.isEmpty || kWorkerRankOptions.contains(t)) return t;
    return '';
  }

  String _rankLabel() => _rank.isEmpty ? '미선택' : _rank;

  String _careerLabel() {
    final label = CareerInputUtils.formatForDisplay(_career);
    if (label.isNotEmpty) return label;
    return '미등록';
  }

  WorkerProfileRead mergeInto(WorkerProfileRead base) {
    return WorkerProfileRead(
      uid: base.uid,
      primarySpecialty: base.primarySpecialty,
      workerRank: _rank,
      career: career,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        if (widget.rankEditable)
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
          )
        else
          _readOnlyValue(context, _rankLabel()),
        if (widget.careerEditable) ...[
          SizedBox(height: gap),
          CareerInputSection(
            initialCareer: _career,
            compact: widget.compact,
            allowStartYearMode: widget.allowStartYearMode,
            onChanged: (value) {
              setState(() => _career = value);
              _notify();
            },
          ),
        ] else ...[
          SizedBox(height: gap),
          Text(
            '경력',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: context.rsi(6)),
          _readOnlyValue(context, _careerLabel()),
        ],
      ],
    );
  }

  Widget _readOnlyValue(BuildContext context, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(12),
        vertical: context.rsi(widget.compact ? 10 : 14),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: cs.surfaceContainerLow,
      ),
      child: Text(
        value,
        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
