import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

Widget toggleWidget({double? width, double? height, Widget? icon, required Widget child}) {
  return SizedBox(
    width: width,
    height: height,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) icon,
            if (icon != null) const SizedBox(width: 5),
            child,
          ],
        ),
      ],
    ),
  );
}
