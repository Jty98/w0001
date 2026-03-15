import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:w0001/presentation/controller/add_cost_controller.dart';
import 'package:w0001/presentation/controller/worker_controller.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';

class HumanScreen extends GetView<WorkerController> {
  const HumanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('사람 관리'),
          actions: [
            TextButton(
                onPressed: () => controller.refreshAction(),
                child: const Text('비우기'))
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildHumanInfoBox(),
            buildEditButton(context, controller),
            const Divider( height: 0, color: Colors.black),
            Expanded(
              child: _buildHumanListView(),
            ),
          ],
        ),
      ),
    );
  }

  Padding _buildHumanListView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: GetBuilder<WorkerController>(
        builder: (controller) => ListView.builder(
          itemCount: controller.filteredWorkerList.length,
          itemBuilder: (context, index) => workerCard(
            controller,
            index,
            controller.filteredWorkerList[index].hname,
            controller.filteredWorkerList[index].hnumber,
            controller.filteredWorkerList[index].hmemo ?? '',
          ),
        ),
      ),
    );
  }

  Padding _buildHumanInfoBox() {
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
              humanInfoTextField(controller, controller.workerNameController,
                  '이름', TextInputType.text, 1),
              humanInfoTextField(controller, controller.workerNumController,
                  '주민등록번호', TextInputType.number, 1),
              humanInfoTextField(controller, controller.workerMemoController,
                  '메모(선택)', TextInputType.text, 4),
            ],
          ),
        ),
      ),
    );
  }

  Container _buildSearchBar() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SearchBar(
        controller: controller.searchWorkerDetailTextContoller,
        leading: const Icon(Icons.search, size: 30),
        hintText: '검색할 사람의 이름을 입력하세요.',
        onChanged: (value) => controller.searchWokerInfo(value),
      ),
    );
  }

  TextButton buildEditButton(context, WorkerController controller) {
    return TextButton(
      onPressed: () {
        controller.editButtonAction();
        FocusScope.of(context).unfocus();
      },
      child: GetBuilder<WorkerController>(
        builder: (controller) => Text(
          controller.isEditing ? '수정하기' : '등록하기',
          style: normalStyle,
        ),
      ),
    );
  }

  Widget workerCard(WorkerController controller, int index, String workerName,
      String workerNum, String workerMemo) {
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
            onPressed: (context) => Get.dialog(
              deleteDialog(
                onPressed: () => controller.updateWorkerDelete(index).then(
                  (value) {
                    FetchData.fetchAllData();
                    Get.find<AddCostController>().selectedWorker = null;
                    Get.back();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      child: InkWell(
        onTap: () =>
            controller.showWorkerInfo(index, workerName, workerNum, workerMemo),
        child: Card(
          color: Colors.blueGrey.withOpacity(0.1),
          child: ListTile(
            title: Text(
              workerName,
              style: bigStyle,
            ),
            leading: IconButton(
              onPressed: () => controller.updateHstarFromWorkerList(index),
              icon: (controller.filteredWorkerList[index].hstar == 0)
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
      WorkerController controller,
      TextEditingController tController,
      String hintText,
      keyboardType,
      maxline) {
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
              LengthLimitingTextInputFormatter(13), // 13자리 숫자만 입력 가능
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
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex <= 6) {
        if (nonZeroIndex % 6 == 0 && nonZeroIndex != text.length) {
          buffer.write('-'); // Add double spaces.
        }
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}
