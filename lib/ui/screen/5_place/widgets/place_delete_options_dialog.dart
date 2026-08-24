import 'package:flutter/material.dart';
import 'package:w0001/domain/place_delete_error.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 삭제: 목록 숨김(soft) / 영구삭제(permanent).
///
/// [permanentOnly]: 이미 보관된 현장에서 호출할 때 true — 숨기기 옵션 숨김.
Future<void> showPlaceDeleteOptionsDialog({
  required BuildContext context,
  required String placeName,
  required Future<void> Function({required bool permanent}) onDelete,
  bool permanentOnly = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final cs = Theme.of(ctx).colorScheme;
          final tt = Theme.of(ctx).textTheme;

          Future<void> run({required bool permanent}) async {
            if (busy) return;
            setModalState(() => busy = true);
            try {
              await onDelete(permanent: permanent);
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            } catch (e) {
              if (!dialogCtx.mounted) return;
              final msg = userMessageForPlaceDeleteFailure(e);
              await showDialog<void>(
                context: dialogCtx,
                builder: (errCtx) => AlertDialog(
                  title: Text(permanent ? '영구 삭제 불가' : '삭제 실패'),
                  content: Text(msg),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(errCtx).pop(),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
            } finally {
              if (dialogCtx.mounted) setModalState(() => busy = false);
            }
          }

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(20),
                  context.rsi(18),
                  context.rsi(20),
                  context.rsi(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '현장 삭제',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: context.rsi(8)),
                    Text(
                      '\'$placeName\'',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: context.rsi(10)),
                    Text(
                      permanentOnly
                          ? '영구 삭제: 인건비·자재비·작업일·수금·수익·체크리스트·공정표·사진 등 '
                              '연관 데이터가 하나도 없을 때만 가능합니다.'
                          : '목록에서 숨기기(권장): 인건비·지출 등 금액 내역은 그대로 남고, '
                              '설정 → 보관 현장에서 다시 복구할 수 있습니다.\n'
                              '영구 삭제: 인건비·자재비·작업일·수금·수익·체크리스트·공정표·사진 등 '
                              '연관 데이터가 하나도 없을 때만 가능합니다.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: context.rsi(16)),
                    if (!permanentOnly) ...[
                      FilledButton(
                        onPressed: busy ? null : () => run(permanent: false),
                        child: Text(busy ? '처리 중…' : '목록에서 숨기기'),
                      ),
                      SizedBox(height: context.rsi(8)),
                    ],
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: dialogCtx,
                                builder: (confirmCtx) => AlertDialog(
                                  title: const Text('영구 삭제 확인'),
                                  content: const Text(
                                    '되돌릴 수 없습니다. 연관 데이터가 있으면 서버에서 차단됩니다. 계속할까요?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(false),
                                      child: const Text('취소'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: cs.error,
                                        foregroundColor: cs.onError,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(true),
                                      child: const Text('영구 삭제'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await run(permanent: true);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.55)),
                      ),
                      child: const Text('영구 삭제'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => Navigator.of(dialogCtx).pop(),
                      child: Text(
                        '취소',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
