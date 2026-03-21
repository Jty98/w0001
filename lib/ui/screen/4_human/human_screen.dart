import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';

class HumanScreen extends ConsumerWidget {
  const HumanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('사람 관리'),
          actions: [
            TextButton(
                onPressed: () => vm.refreshAction(),
                child: const Text('비우기'))
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(vm),
            _buildHumanInfoBox(vm),
            _buildEditButton(context, ref, vm),
            const Divider(height: 0, color: Colors.black),
            Expanded(
              child: _buildHumanListView(ref, vm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumanListView(WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: ListView.builder(
        itemCount: state.filteredWorkerList.length,
        itemBuilder: (context, index) => workerCard(
          context,
          ref,
          vm,
          index,
          state.filteredWorkerList[index].hname,
          state.filteredWorkerList[index].hnumber,
          state.filteredWorkerList[index].hmemo ?? '',
        ),
      ),
    );
  }

  Widget _buildHumanInfoBox(WorkerViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(width: 2, color: Colors.black),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              humanInfoTextField(vm, vm.workerNameController, '이름',
                  TextInputType.text, 1),
              humanInfoTextField(vm, vm.workerNumController, '주민등록번호',
                  TextInputType.number, 1),
              humanInfoTextField(vm, vm.workerMemoController, '메모(선택)',
                  TextInputType.text, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(WorkerViewModel vm) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SearchBar(
        controller: vm.searchWorkerDetailTextContoller,
        leading: const Icon(Icons.search, size: 30),
        hintText: '검색할 사람의 이름을 입력하세요.',
        onChanged: vm.searchWokerInfo,
      ),
    );
  }

  Widget _buildEditButton(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return TextButton(
      onPressed: () async {
        await vm.editButtonAction(context);
        if (context.mounted) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Text(
        state.isEditing ? '수정하기' : '등록하기',
        style: normalStyle,
      ),
    );
  }

  Widget workerCard(
    BuildContext context,
    WidgetRef ref,
    WorkerViewModel vm,
    int index,
    String workerName,
    String workerNum,
    String workerMemo,
  ) {
    final state = ref.watch(workerProvider);
    return Slidable(
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: '삭제',
            onPressed: (slidableContext) {
              final container = ProviderScope.containerOf(slidableContext);
              showDialog<void>(
                context: slidableContext,
                builder: (dialogCtx) => deleteDialog(
                  onPressed: () async {
                    await vm.updateWorkerDelete(index);
                    await FetchData.fetchAllData();
                    container
                        .read(addCostProvider.notifier)
                        .clearSelectedWorker();
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
      child: InkWell(
        onTap: () =>
            vm.showWorkerInfo(index, workerName, workerNum, workerMemo),
        child: Card(
          color: Colors.blueGrey.withValues(alpha: 0.1),
          child: ListTile(
            title: Text(
              workerName,
              style: bigStyle,
            ),
            leading: IconButton(
              onPressed: () => vm.updateHstarFromWorkerList(index),
              icon: (state.filteredWorkerList[index].hstar == 0)
                  ? const Icon(
                      Icons.star_border,
                      color: Colors.grey,
                    )
                  : const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
            ),
            subtitle: Text(
              workerNum,
              style: smallStyle,
            ),
          ),
        ),
      ),
    );
  }

  Widget humanInfoTextField(
    WorkerViewModel vm,
    TextEditingController tController,
    String hintText,
    TextInputType keyboardType,
    int maxline,
  ) {
    return TextField(
      maxLines: maxline,
      controller: tController,
      decoration: InputDecoration(
        labelText: hintText,
        semanticCounterText: hintText,
        labelStyle: mediumStyle,
        isDense: true,
        constraints: const BoxConstraints(maxHeight: 105),
      ),
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
              NumberFormatter(),
            ]
          : [],
    );
  }
}

class NumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex <= 6) {
        if (nonZeroIndex % 6 == 0 && nonZeroIndex != text.length) {
          buffer.write('-');
        }
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}
