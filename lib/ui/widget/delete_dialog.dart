import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/util/responsive_layout.dart';

Dialog deleteDialog({VoidCallback? onPressed, String? content}) {
  return Dialog(
    child: Builder(
      builder: (context) {
        final tt = Theme.of(context).textTheme;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rs(10)),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(context.rs(10)),
                child: Text(
                  '알림',
                  style: tt.titleMedium,
                ),
              ),
              Text(content ?? '정말 삭제하시겠습니까?', style: tt.bodyLarge),
              rsV(context, 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onPressed,
                    child: Text(
                      '확인',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    ),
  );
}
