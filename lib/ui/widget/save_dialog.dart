import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/util/text_style.dart';

Dialog saveDialog(
    {required String text,
    String? title,
    double? width,
    Widget? child,
    TextStyle? textStyle,
    TextStyle? titleStyle}) {
  return Dialog(
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color.fromARGB(255, 239, 240, 240)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              title ?? '알림',
              style: titleStyle ?? bigStyle,
            ),
          ),
          Text(text, style: textStyle ?? normalStyle),
          child ?? const SizedBox.shrink(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Get.back();
                },
                child: const Text(
                  '확인',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          )
        ],
      ),
    ),
  );
}

Dialog pageViewDialog(
    {required String text,
    String? title,
    double? height,
    List<Widget>? children,
    TextStyle? textStyle,
    TextStyle? titleStyle}) {
  return Dialog(
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color.fromARGB(255, 239, 240, 240)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              title ?? '알림',
              style: titleStyle ?? bigStyle,
            ),
          ),
          Text(text, style: textStyle ?? normalStyle),
          SizedBox(
            height: height ?? 500,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  Get.back();
                },
                child: const Text(
                  '확인',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          )
        ],
      ),
    ),
  );
}
