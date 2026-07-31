import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

class SelectDateButton extends ConsumerWidget {
  const SelectDateButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(14)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rs(14)),
        onTap: () => vm.changeDateTime(context),
        child: Padding(
          padding: ResponsiveLayout.symmetric(
            context,
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month,
                  size: context.rsi(20), color: cs.primary),
              rsH(context, 10),
              Expanded(
                child: Text(
                  formatDateTimeWeekDayToString(state.selectDay),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color.fromARGB(255, 70, 70, 70),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: context.rsi(20),
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
