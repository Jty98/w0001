import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/util/responsive_layout.dart';

Dialog saveDialog({
  required String text,
  String? title,
  double? width,
  Widget? child,
  TextStyle? textStyle,
  TextStyle? titleStyle,
}) {
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
                  title ?? '알림',
                  style: titleStyle ?? tt.titleMedium,
                ),
              ),
              Text(text, style: textStyle ?? tt.bodyLarge),
              child ?? const SizedBox.shrink(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: Text(
                      '확인',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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

Dialog pageViewDialog({
  required String text,
  String? title,
  double? height,
  List<Widget>? children,
  TextStyle? textStyle,
  TextStyle? titleStyle,
}) {
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
                  title ?? '알림',
                  style: titleStyle ?? tt.titleMedium,
                ),
              ),
              Text(text, style: textStyle ?? tt.bodyLarge),
              SizedBox(
                height: context.rs(height ?? 500),
                child: Padding(
                  padding: ResponsiveLayout.symmetric(context, horizontal: 10),
                  child: PageView(
                    children: children ?? [],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: Text(
                      '확인',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
