import 'package:flutter/material.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 묶음 `title` · `업로드일` 수정 후 [onSubmit] 결과로 스낵바 등 처리.
Future<void> showPlacePhotoGroupMetaEditDialog({
  required BuildContext context,
  required PlacePhotoGroupModel group,
  required Future<String?> Function({
    required String title,
    required String photoDateIso,
  }) onSubmit,
}) async {
  final titleCtrl = TextEditingController(text: group.title.trim());
  var pickedDay = DateTime.tryParse(group.photoDate.length >= 10
          ? group.photoDate.substring(0, 10)
          : '') ??
      DateTime.now();

  Future<void> pickDay(BuildContext parentCtx, StateSetter setS) async {
    final chosen = await showDialog<DateTime>(
      context: parentCtx,
      builder: (calendarCtx) {
        DateTime day = pickedDay;
        final screenH = MediaQuery.sizeOf(calendarCtx).height;
        final maxHeight = (screenH * 0.60).clamp(400.0, 520.0).toDouble();
        final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();
        final tt = Theme.of(calendarCtx).textTheme;
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: EdgeInsets.only(bottom: calendarCtx.rsi(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: calendarCtx.rsi(10)),
                    child: Text(
                      '작업일 선택',
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ScrollableCalendarWidget(
                    height: calHeight,
                    initialSelectedDay: day,
                    useSingleDaySelection: true,
                    showViewModeToggle: false,
                    disableDateSelectionHighlight: true,
                    onDayPicked: (d) => day = d,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(calendarCtx).pop(),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(calendarCtx).pop(day),
                        child: Text(
                          '확인',
                          style: TextStyle(
                              color: Theme.of(calendarCtx).colorScheme.primary),
                        ),
                      ),
                      SizedBox(width: calendarCtx.rsi(8)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      pickedDay = DateTime(chosen.year, chosen.month, chosen.day);
      setS(() {});
    }
  }

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      String dateLabel(BuildContext _) {
        return '${pickedDay.year}.${pickedDay.month.toString().padLeft(2, '0')}.${pickedDay.day.toString().padLeft(2, '0')}';
      }

      return StatefulBuilder(
        builder: (dialogCtx, setS) => AlertDialog(
          title: const Text('작업 묶음 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '작업명',
                    hintText: '예: 거실 타일 줄눈',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 80,
                  buildCounter: (context,
                          {required currentLength,
                          required maxLength,
                          required isFocused}) =>
                      null,
                ),
                SizedBox(height: dialogCtx.rsi(12)),
                OutlinedButton.icon(
                  onPressed: () => pickDay(dialogCtx, setS),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('업로드일: ${dateLabel(dialogCtx)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                '취소',
                style: TextStyle(
                    color: Theme.of(dialogCtx).colorScheme.onSurfaceVariant),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final ti = titleCtrl.text.trim();
                if (ti.isEmpty) {
                  ScaffoldMessenger.maybeOf(dialogCtx)?.showSnackBar(
                    const SnackBar(content: Text('작업명을 입력해 주세요')),
                  );
                  return;
                }
                final iso = formatDateTimeToIsoDate(pickedDay);
                final err = await onSubmit(title: ti, photoDateIso: iso);
                if (!dialogCtx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(dialogCtx)
                      .showSnackBar(SnackBar(content: Text(err)));
                  return;
                }
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
    },
  );

  titleCtrl.dispose();
}
