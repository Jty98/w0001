import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/ui/widget/calendar/my_calendar.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/work_cost_delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/total_cost_card.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readOnly = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u != null && !u.role.canEditCalendarExpenses,
          orElse: () => false,
        );
    return Scaffold(
      body: Column(
        children: [
          const CalendarWidget(),
          _buildTotalPriceBar(ref, readOnly),
          _buildSelectedCategoryText(context, ref),
          Expanded(
            child: _buildListView(context, ref, readOnly),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategoryText(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: ResponsiveLayout.only(context, left: 12, top: 4, right: 12),
      child: Text(
        '${state.selectedFilterType.category} ${getPrice(price: vm.getFilteredListPrice)}',
        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    bool readOnly,
  ) {
    ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: ResponsiveLayout.only(context, left: 12, top: 6, right: 12),
      child: vm.placeCount == 0
          ? Center(
              child: Text(
                '조회된 데이터가 없습니다.',
                style: tt.bodyMedium,
              ),
            )
          : ListView.builder(
              itemCount: vm.placeCount,
              itemBuilder: (context, index) {
                final placeInfo = vm.getUniquePlaceNameAndComplete()[index];
                final pname = placeInfo['pname'];
                final pcomplete = placeInfo['pcomplete'];
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rs(16)),
                    side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.55)),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    shape: const Border(),
                    tilePadding: ResponsiveLayout.symmetric(
                      context,
                      horizontal: 10,
                    ),
                    leading: Icon(
                      pcomplete == 0 ? null : Icons.check_box_rounded,
                      color: cs.onSurfaceVariant,
                      size: context.rsi(20),
                    ),
                    title: Text(
                      pname,
                      style: tt.titleMedium,
                    ),
                    expandedAlignment: Alignment.centerLeft,
                    children: [
                      Padding(
                        padding: ResponsiveLayout.only(
                          context,
                          left: 12,
                          top: 6,
                          right: 12,
                          bottom: 12,
                        ),
                        child: Column(
                          children: [
                            for (var element in vm.filteredTotalCostList
                                .where((e) => e.pname == pname)
                                .toList())
                              if (readOnly)
                                Padding(
                                  padding: EdgeInsets.only(bottom: context.rs(8)),
                                  child: TotalCostCard(
                                    category: element.category,
                                    name: element.name,
                                    price: element.price,
                                    wcomplete: element.wcomplete,
                                    wcompletedAt: element.wcompletedAt,
                                  ),
                                )
                              else
                                Slidable(
                                  closeOnScroll: true,
                                  startActionPane: element.category == 'w'
                                      ? ActionPane(
                                          motion: const DrawerMotion(),
                                          children: [
                                            SlidableAction(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              backgroundColor:
                                                  element.wcomplete == 1
                                                      ? cs.primary
                                                      : cs.tertiary,
                                              icon: element.wcomplete == 1
                                                  ? Icons.autorenew_outlined
                                                  : Icons.check_circle,
                                              label: element.wcomplete == 1
                                                  ? '미지급으로 변경'
                                                  : '지급 완료',
                                              onPressed: (slidableCtx) async {
                                                final msg =
                                                    await vm.updateWComplete(
                                                        element.wcomplete,
                                                        element.id);
                                                if (!slidableCtx.mounted) {
                                                  return;
                                                }
                                                await showDialog<void>(
                                                  context: slidableCtx,
                                                  builder: (_) =>
                                                      saveDialog(text: msg),
                                                );
                                              },
                                            ),
                                          ],
                                        )
                                      : null,
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    children: [
                                      SlidableAction(
                                        borderRadius: BorderRadius.circular(10),
                                        backgroundColor: cs.error,
                                        icon: Icons.delete,
                                        label: '삭제',
                                        onPressed: (slidableCtx) async {
                                          if (element.category == 'w') {
                                            final pwdid = await vm
                                                .placeWorkDayPwdidForWorkCost(
                                                    element);
                                            if (!slidableCtx.mounted) return;
                                            final choice =
                                                await showWorkCostDeleteDialog(
                                              slidableCtx,
                                              placeName: element.pname,
                                              workerName: element.name,
                                              dateLabel: element.date,
                                              hasLinkedWorkDay: pwdid != null,
                                              workrole: element.workrole,
                                            );
                                            if (choice == null ||
                                                choice ==
                                                    WorkCostDeleteChoice
                                                        .cancel ||
                                                !slidableCtx.mounted) {
                                              return;
                                            }
                                            await vm.deleteWorkCostLinked(
                                              wid: element.id,
                                              pwdid: choice ==
                                                      WorkCostDeleteChoice
                                                          .costAndWorkDay
                                                  ? pwdid
                                                  : null,
                                            );
                                            return;
                                          }
                                          await showDialog<void>(
                                            context: slidableCtx,
                                            builder: (dialogCtx) =>
                                                deleteDialog(
                                              onPressed: () async {
                                                await vm.deleteCost(
                                                    element.category,
                                                    element.id);
                                                if (dialogCtx.mounted) {
                                                  Navigator.of(dialogCtx).pop();
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  child: _editableCard(context, ref, element),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTotalPriceBar(WidgetRef ref, bool readOnly) {
    final state = ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);
    final callbacks = readOnly
        ? <String, CategoryTapCallback>{}
        : {
            for (final type in FilterType.values)
              type.category: (_) => vm.setFilterType(type),
          };
    return TotalPriceBar(
      totalCostList: state.totalCostList,
      categoryTapCallbacks: callbacks,
      compact: true,
    );
  }

  Widget _editableCard(
    BuildContext context,
    WidgetRef ref,
    TotalCostModel element,
  ) {
    final vm = ref.read(calendarProvider.notifier);
    return InkWell(
      onTap: () {
        vm.prepareEditDialog(element);
        showDialog<void>(
          context: context,
          builder: (dialogContext) => Consumer(
            builder: (context, ref, _) {
              final dialogState = ref.watch(calendarProvider);
              final dialogVm = ref.read(calendarProvider.notifier);
              return Dialog(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: context.rs(15)),
                        child: Text(
                          '수정',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async =>
                            dialogVm.pickDialogDate(dialogContext),
                        icon: Icon(
                          Icons.date_range_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          formatDateTimeWeekDayToString(
                              dialogState.dialogDateTime),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color.fromARGB(255, 105, 112, 127),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Visibility(
                        visible: element.category == 'w' ? false : true,
                        child: SizedBox(
                          height: 60,
                          width: 230,
                          child: DropdownSearch<String>(
                            items: categoryList,
                            onChanged: (value) =>
                                dialogVm.categoryChangeAction(value!),
                            selectedItem: dialogState.dropDownSelectedCategory,
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: context.rsi(10),
                          bottom: context.rsi(3),
                        ),
                        child: AddTextField(
                          tController: dialogVm.mNameController,
                          labelText: '항목',
                          isPrice: false,
                          height: 60,
                          keyboardType: TextInputType.text,
                          readOnly: element.category == 'w' ? true : false,
                          onChanged: (value) => dialogVm.clearEditAlert(),
                        ),
                      ),
                      AddTextField(
                        tController: dialogVm.mPriceController,
                        labelText: '금액',
                        isPrice: true,
                        height: 60,
                        keyboardType: TextInputType.number,
                        readOnly: false,
                        onChanged: (value) => dialogVm.clearEditAlert(),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: context.rsi(5)),
                        child: Text(
                          dialogState.alertText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              dialogVm.clearEditAlert();
                              Navigator.of(dialogContext).pop();
                            },
                            child: Text(
                              '취소',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final ok = await dialogVm.updateCost(
                                element.category,
                                element.id,
                                dialogState.dialogDateTime.toString(),
                              );
                              if (ok && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: const Text('수정'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      child: TotalCostCard(
        category: element.category,
        name: element.name,
        price: element.price,
        wcomplete: element.wcomplete,
        wcompletedAt: element.wcompletedAt,
      ),
    );
  }
}
