import 'package:flutter/material.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'compact_range_calendar.dart';
import 'models.dart';

class DateRangePickerSheet extends StatefulWidget {
  const DateRangePickerSheet({
    required this.task,
    required this.processStart,
    required this.processEnd,
    this.initialStart,
    this.initialEnd,
    required this.allProcessEvents,
    this.gridStart,
    this.onProcessDateModified,
  });

  final ProcessScheduleTask? task;
  final DateTime processStart;
  final DateTime processEnd;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final List<ProcessEventData> allProcessEvents;
  final DateTime? gridStart;
  final Function(DateTime newStart, DateTime newEnd)? onProcessDateModified;

  @override
  State<DateRangePickerSheet> createState() => DateRangePickerSheetState();
}

class DateRangePickerSheetState extends State<DateRangePickerSheet> {
  late DateTime _selectedStart;
  late DateTime _selectedEnd;

  @override
  void initState() {
    super.initState();
    _selectedStart = widget.initialStart ?? widget.processStart;
    _selectedEnd = widget.initialEnd ?? widget.processEnd;
  }

  /// 선택한 날짜가 공정 범위를 벗어나는지 확인
  bool _isOutOfProcessRange(DateTime start, DateTime end) {
    return start.isBefore(widget.processStart) ||
        end.isAfter(widget.processEnd);
  }

  /// 범위 초과 시 공정 수정 제안 다이얼로그
  Future<bool> _showProcessModificationDialog(
      DateTime start, DateTime end) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          size: context.rs(48),
        ),
        title: const Text('공정 기간 불일치'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '선택한 기간이 공정 범위를 벗어났습니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: context.rsi(16)),
            Container(
              padding: ResponsiveLayout.all(context, 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.rs(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: context.rs(16),
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(width: context.rsi(8)),
                      Text(
                        '현재 공정 기간',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rsi(4)),
                  Text(
                    '${widget.processStart.month}/${widget.processStart.day} ~ ${widget.processEnd.month}/${widget.processEnd.day}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: context.rsi(12)),
                  Row(
                    children: [
                      Icon(
                        Icons.new_label,
                        size: context.rs(16),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: context.rsi(8)),
                      Text(
                        '선택한 기간',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rsi(4)),
                  Text(
                    '${start.month}/${start.day} ~ ${end.month}/${end.day}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.rsi(16)),
            Text(
              '공정 기간을 선택한 날짜로 수정하시겠습니까?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('공정 기간 수정'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: ResponsiveLayout.all(context, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task?.name ?? '날짜 선택',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '투입 기간을 선택하세요',
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: context.rsi(12)),

            // 커스텀 캘린더
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.rsi(12)),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(context.rs(10)),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: CompactRangeCalendar(
                        processStart: widget.processStart,
                        processEnd: widget.processEnd,
                        initialStart: _selectedStart,
                        initialEnd: _selectedEnd,
                        allProcessEvents: widget.allProcessEvents,
                        selectedTask: widget.task,
                        onRangeChanged: (start, end) async {
                          // 공정 범위 체크
                          final isInRange = !_isOutOfProcessRange(start, end);

                          if (isInRange) {
                            // 범위 내 - 정상 선택
                            setState(() {
                              _selectedStart = start;
                              _selectedEnd = end;
                            });
                          } else {
                            // 범위 초과 - 공정 수정 제안
                            final shouldModify =
                                await _showProcessModificationDialog(
                                    start, end);

                            if (shouldModify) {
                              // 공정 기간 수정 콜백 호출
                              widget.onProcessDateModified?.call(start, end);

                              // 선택된 날짜 업데이트
                              setState(() {
                                _selectedStart = start;
                                _selectedEnd = end;
                              });

                              // 사용자에게 피드백
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('공정 기간이 수정되었습니다'),
                                    backgroundColor: cs.primary,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: context.rsi(20)),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rs(52)),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                SizedBox(width: context.rsi(12)),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'start': _selectedStart,
                        'end': _selectedEnd,
                      });
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rs(52)),
                    ),
                    child: const Text('선택 완료'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 인력 상세 정보 수정 시트
