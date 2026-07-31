import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool isCopyableDisplayValue(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty &&
      trimmed != '미등록' &&
      trimmed != '등록됨' &&
      trimmed != '-';
}

Future<void> copyDisplayValue(
  BuildContext context, {
  required String label,
  required String value,
}) async {
  final trimmed = value.trim();
  if (!isCopyableDisplayValue(trimmed)) return;
  await Clipboard.setData(ClipboardData(text: trimmed));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label을(를) 복사했습니다.')),
  );
}
