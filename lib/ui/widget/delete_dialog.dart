import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/util/text_style.dart';

Dialog deleteDialog( {VoidCallback? onPressed, String? content}) {
  return Dialog(
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Text(
                          '알림',
                          style: bigStyle,
                        ),
                      ),
                      Text(content ?? '정말 삭제하시겠습니까?', style: normalStyle),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              Get.back();
                            },
                            child: const Text('취소', style: TextStyle( color: Colors.red),),
                          ),
                          TextButton(
                            onPressed: onPressed,
                            child: const Text('확인'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
}
