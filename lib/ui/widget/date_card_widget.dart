import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/add_cost_controller.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

class SelectDateButton extends GetView<AddCostController> {
  const SelectDateButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      height: 45,
      width: 236,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton.icon(
          onPressed: () async => await controller.changeDateTime(context),
          icon: const Icon(
            Icons.calendar_month,
            size: 25,
            color: Colors.blueGrey,
          ),
          label: GetBuilder<AddCostController>(
            builder: (controller) => Text(
              formatDateTimeWeekDayToString(controller.selectDay),
              style: cardDateStyle,
            ),
          ),
        ),
      ),
    );
  }
}
