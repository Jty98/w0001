import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 이미지 업로드·첨부 중 모달 로딩(취소 불가).
Future<T> runWithImageUploadProgressDialog<T>({
  required BuildContext context,
  required Future<T> Function(
    void Function(String message) setMessage,
  ) body,
}) async {
  if (!context.mounted) {
    return body((_) {});
  }

  final messageNotifier = ValueNotifier<String>('이미지 준비 중…');

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dCtx) => PopScope(
      canPop: false,
      child: ValueListenableBuilder<String>(
        valueListenable: messageNotifier,
        builder: (_, msg, __) => AlertDialog(
          content: SizedBox(
            width: dCtx.rs(280),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                SizedBox(width: dCtx.rsi(16)),
                Expanded(
                  child: Text(
                    msg,
                    style: Theme.of(dCtx).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  try {
    return await body((m) {
      messageNotifier.value = m;
    });
  } finally {
    messageNotifier.dispose();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
