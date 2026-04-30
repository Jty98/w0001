import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_chart_views.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_excel_export.dart';

String _sanitizeFileStem(String raw) =>
    raw.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

String _timestampForFileName() {
  final d = DateTime.now();
  return '${d.year}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}_'
      '${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// 바텀시트로 엑셀 추출 vs 이미지 공유 선택.
Future<void> showProcessScheduleShareSheet({
  required BuildContext context,
  required ColorScheme cs,
  required ProcessScheduleData data,
  required String placeName,
}) async {
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '공정표 공유',
                textAlign: TextAlign.center,
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(sheetCtx)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.55),
                  child: Icon(
                    Icons.table_chart_rounded,
                    color: Theme.of(sheetCtx).colorScheme.primary,
                  ),
                ),
                title: const Text('엑셀로 추출'),
                subtitle: const Text('.xlsx — 날짜 열·공정별 색, 앱 표와 같은 구조'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _shareExcel(
                    context: context,
                    data: data,
                    placeName: placeName,
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(sheetCtx).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.image_outlined,
                    color: Theme.of(sheetCtx).colorScheme.secondary,
                  ),
                ),
                title: const Text('이미지로 공유'),
                subtitle: const Text('PNG — 요약표 화면과 동일 레이아웃'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _shareImage(
                    context: context,
                    cs: cs,
                    data: data,
                    placeName: placeName,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _shareExcel({
  required BuildContext context,
  required ProcessScheduleData data,
  required String placeName,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final bytes =
      buildProcessScheduleExcelBytes(data: data, placeName: placeName);
  if (bytes == null) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('엑셀을 만들 수 없습니다.')),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final path =
      '${dir.path}/${_sanitizeFileStem(placeName)}_공정표_${_timestampForFileName()}.xlsx';

  try {
    final file = File(path);
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '$placeName 공정표',
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('공유에 실패했습니다: $e')));
  }
}

Future<void> _shareImage({
  required BuildContext context,
  required ColorScheme cs,
  required ProcessScheduleData data,
  required String placeName,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (data.dayCount < 1) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('공사 일 범위가 없어 이미지를 만들 수 없습니다.')),
    );
    return;
  }

  final dates = ProcessScheduleEditor.columnDates(data);
  final labels = [
    for (final t in data.tasks) ProcessScheduleEditor.labelCenterDayIndices(t),
  ];

  final w = chartContentW(data);
  final h = chartContentH(data);
  final shot = ScreenshotController();

  final Uint8List pngBytes;
  try {
    pngBytes = await shot.captureFromWidget(
      Material(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.97),
        child: SizedBox(
          width: w,
          height: h,
          child: ProcessScheduleOverviewChart(
            cs: cs,
            data: data,
            dates: dates,
            labelCentersByRow: labels,
            onCellTap: (_, __) {},
          ),
        ),
      ),
      context: context,
      delay: const Duration(milliseconds: 520),
      targetSize: Size(w, h),
      pixelRatio: 2,
    );
  } catch (e, st) {
    debugPrint('Process schedule image capture failed: $e\n$st');
    messenger?.showSnackBar(
      const SnackBar(content: Text('이미지를 만들 수 없습니다. 다시 시도해 주세요.')),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final outPath =
      '${dir.path}/${_sanitizeFileStem(placeName)}_공정표_${_timestampForFileName()}.png';

  try {
    await File(outPath).writeAsBytes(pngBytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(outPath)],
        subject: '$placeName 공정표',
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('공유에 실패했습니다: $e')));
  }
}
