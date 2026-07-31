import 'package:flutter/material.dart';
import 'package:w0001/ui/screen/0_auth/widgets/career_input_section.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 경력 — 기본 보기 모드, [수정] 후 휠 편집 (인력관리·회원관리 공통).
class WorkerCareerField extends StatefulWidget {
  const WorkerCareerField({
    super.key,
    required this.career,
    required this.onChanged,
    this.readOnlyUntilEdit = true,
    this.compact = false,
    this.allowStartYearMode = true,
    this.autoCommit = true,
  });

  final String career;
  final ValueChanged<String> onChanged;
  final bool readOnlyUntilEdit;
  final bool compact;
  final bool allowStartYearMode;

  /// `true`(기본): 휠 변경마다 [onChanged] 호출 — 인력 등록 폼.
  /// `false`: [저장] 버튼으로만 [onChanged] 호출 — 상세 화면.
  final bool autoCommit;

  @override
  State<WorkerCareerField> createState() => _WorkerCareerFieldState();
}

class _WorkerCareerFieldState extends State<WorkerCareerField> {
  var _editing = false;
  late String _draftCareer;

  @override
  void initState() {
    super.initState();
    _draftCareer = CareerInputUtils.formatForDisplay(widget.career);
    _editing = !widget.readOnlyUntilEdit;
  }

  @override
  void didUpdateWidget(WorkerCareerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.career != widget.career) {
      _draftCareer = CareerInputUtils.formatForDisplay(widget.career);
    }
  }

  String get _displayLabel {
    final raw = (_editing ? _draftCareer : widget.career).trim();
    if (raw.isEmpty) return '미등록';
    return CareerInputUtils.formatForDisplay(raw);
  }

  void _cancelEdit() {
    setState(() {
      _draftCareer = CareerInputUtils.formatForDisplay(widget.career);
      _editing = false;
    });
  }

  void _commitEdit() {
    widget.onChanged(_draftCareer);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final placeholder = _displayLabel == '미등록';

    if (widget.readOnlyUntilEdit && !_editing) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(context.rsi(12)),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(10),
            context.rsi(8),
            context.rsi(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history_edu_outlined,
                size: context.rs(20),
                color: cs.primary,
              ),
              SizedBox(width: context.rsi(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '경력',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.rsi(2)),
                    Text(
                      _displayLabel,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: placeholder ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _draftCareer =
                      CareerInputUtils.formatForDisplay(widget.career);
                  _editing = true;
                }),
                icon: Icon(Icons.edit_outlined, size: context.rsi(16)),
                label: const Text('수정'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: context.rsi(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareerInputSection(
          initialCareer: _draftCareer,
          compact: widget.compact,
          allowStartYearMode: widget.allowStartYearMode,
          onChanged: (value) {
            _draftCareer = value;
            if (widget.autoCommit) {
              widget.onChanged(value);
            }
          },
        ),
        if (widget.readOnlyUntilEdit) ...[
          SizedBox(height: context.rsi(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelEdit,
                child: const Text('취소'),
              ),
              if (!widget.autoCommit) ...[
                SizedBox(width: context.rsi(8)),
                FilledButton.tonal(
                  onPressed: _commitEdit,
                  child: const Text('저장'),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

String workerCareerDraftFromYears(int? years) {
  if (years == null) return '';
  return CareerInputUtils.formatYears(years);
}
