import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/ui/widget/image_upload_progress_dialog.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';

Future<List<Map<String, dynamic>>?> prepareBulkSiteInstructionBlocks({
  required BuildContext context,
  required bool mounted,
  required bool touchedByUser,
  required List<WorkerAnnouncementBlock> globalWorkInstructionBlocks,
}) async {
  if (!touchedByUser ||
      globalWorkInstructionBlocks.isEmpty ||
      workInstructionBlocksLookEmpty(globalWorkInstructionBlocks)) {
    return null;
  }

  final doc = WorkerAnnouncementQuillCodec.decodeToDocument(
    globalWorkInstructionBlocks,
  );

  Document finalDoc = doc;
  if (WorkerAnnouncementQuillCodec.documentHasLocalImages(doc)) {
    debugPrint('📤 [일괄 투입] 작업지시 이미지 업로드 시작...');
    if (!mounted) return null;

    finalDoc = await runWithImageUploadProgressDialog<Document>(
      context: context,
      body: (setMessage) async {
        return await WorkerAnnouncementQuillCodec.uploadLocalImagesInDocument(
          doc,
          category: ImageUploadCategory.placeImage,
          onProgress: (current, total) {
            setMessage('이미지 업로드 중… ($current/$total)');
            debugPrint('   - 이미지 업로드: $current/$total');
          },
        );
      },
    );

    if (!mounted) return null;
    debugPrint('✅ [일괄 투입] 작업지시 이미지 업로드 완료');
  }

  final uploadedBlocks = WorkerAnnouncementQuillCodec.blocksForApi(finalDoc);
  return uploadedBlocks.map((block) => block.toJson()).toList();
}
