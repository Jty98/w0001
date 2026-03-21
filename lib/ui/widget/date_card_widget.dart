import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

class SelectDateButton extends ConsumerWidget {
  const SelectDateButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

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
          onPressed: () async => vm.changeDateTime(context),
          icon: const Icon(
            Icons.calendar_month,
            size: 25,
            color: Colors.blueGrey,
          ),
          label: Text(
            formatDateTimeWeekDayToString(state.selectDay),
            style: cardDateStyle,
          ),
        ),
      ),
    );
  }
}
