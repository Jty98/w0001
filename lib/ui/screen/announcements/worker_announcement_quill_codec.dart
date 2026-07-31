import 'dart:async';
import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/announcements/announcement_image_strip_embed.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';

/// 서버 변경 전까지 Quill 문서(JSON ops)를 한 개의 텍스트 블록에 싣습니다.
abstract final class WorkerAnnouncementQuillCodec {
  WorkerAnnouncementQuillCodec._();

  static const magic = kWorkerAnnouncementQuillMagic;

  static bool isQuillEnvelopeText(String text) =>
      text.trimLeft().startsWith(magic);

  static bool blocksLookLikeStoredQuill(List<WorkerAnnouncementBlock> blocks) {
    if (blocks.length != 1) return false;
    return switch (blocks.first) {
      WorkerAnnouncementTextBlock(:final text) => isQuillEnvelopeText(text),
      _ => false,
    };
  }

  /// Quill 저장 포맷이면 디코드, 아니면 레거시 블록 목록으로 [Document]를 만듭니다.
  ///
  /// 서버·붙여넣기 등으로 들어온 `color`/`background`가 `transparent` 또는 알파 0이면
  /// [flutter_quill]이 글자를 투명으로 그리므로 제거한다.
  static Document decodeToDocument(List<WorkerAnnouncementBlock> blocks) {
    final ops = decodeDeltaOps(blocks);
    if (ops != null) {
      try {
        final doc = Document.fromDelta(Delta.fromJson(ops));
        return _documentWithoutInvisibleTextColors(doc);
      } catch (_) {}
    }
    return _documentWithoutInvisibleTextColors(legacyBlocksToDocument(blocks));
  }

  static List<dynamic>? decodeDeltaOps(List<WorkerAnnouncementBlock> blocks) {
    if (!blocksLookLikeStoredQuill(blocks)) return null;
    try {
      final b = blocks.first as WorkerAnnouncementTextBlock;
      final raw =
          jsonDecode(b.text.substring(b.text.indexOf(magic) + magic.length));
      if (raw is List) return raw;
      if (raw is Map<String, dynamic> && raw['ops'] is List) {
        return raw['ops'] as List<dynamic>;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static WorkerAnnouncementBlock encodeDocument(Document doc) {
    final clean = _documentWithoutInvisibleTextColors(doc);
    final jsonList = clean.toDelta().toJson();
    return WorkerAnnouncementTextBlock('$magic${jsonEncode(jsonList)}');
  }

  static Document _documentWithoutInvisibleTextColors(Document doc) {
    try {
      final raw = doc.toDelta().toJson();
      final cleaned = _sanitizeDeltaOpsJson(List<dynamic>.from(raw));
      return Document.fromDelta(Delta.fromJson(cleaned));
    } catch (_) {
      return doc;
    }
  }

  static List<dynamic> _sanitizeDeltaOpsJson(List<dynamic> ops) {
    return ops.map((op) {
      if (op is! Map) return op;
      final m = Map<String, dynamic>.from(op);
      final attrs = m['attributes'];
      if (attrs is Map) {
        final a = Map<String, dynamic>.from(attrs);
        for (final key in <String>['color', 'background']) {
          if (!a.containsKey(key)) continue;
          if (_colorAttributeIsInvisible(a[key])) {
            a.remove(key);
          }
        }
        if (a.isEmpty) {
          m.remove('attributes');
        } else {
          m['attributes'] = a;
        }
      }
      return m;
    }).toList();
  }

  /// Quill `color` / `background` 값이 화면에 안 보이게 만드는 경우.
  static bool _colorAttributeIsInvisible(Object? raw) {
    if (raw == null) return true;
    if (raw is! String) return false;
    final s = raw.trim();
    if (s.isEmpty) return true;
    final lower = s.toLowerCase();
    if (lower == 'transparent') return true;
    if (lower.startsWith('rgba')) {
      try {
        var inner = lower.substring(5);
        if (inner.endsWith(')')) {
          inner = inner.substring(0, inner.length - 1);
        }
        final parts = inner.split(',').map((e) => e.trim()).toList();
        if (parts.length >= 4) {
          final a = double.tryParse(parts[3]);
          if (a != null && a <= 0.001) return true;
        }
      } catch (_) {}
      return false;
    }
    if (!lower.startsWith('#')) return false;
    var hex = lower.replaceFirst('#', '');
    if (hex.length == 6) {
      return false;
    }
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val == null) return false;
      final alpha = (val >> 24) & 0xFF;
      return alpha == 0;
    }
    return false;
  }

  static bool _deltaOpsHasInvisibleColor(List<dynamic> ops) {
    for (final op in ops) {
      if (op is! Map) continue;
      final attrs = op['attributes'];
      if (attrs is! Map) continue;
      for (final key in <String>['color', 'background']) {
        if (attrs.containsKey(key) && _colorAttributeIsInvisible(attrs[key])) {
          return true;
        }
      }
    }
    return false;
  }

  /// 편집 중 투명 `color`/`background` 속성이 붙으면 즉시 제거한다.
  static StreamSubscription<DocChange>? attachInvisibleColorGuard(
    QuillController controller,
  ) {
    var fixing = false;
    void sanitize() {
      if (fixing) return;
      final ops = List<dynamic>.from(controller.document.toDelta().toJson());
      if (!_deltaOpsHasInvisibleColor(ops)) return;
      fixing = true;
      try {
        final sel = controller.selection;
        final cleaned =
            _documentWithoutInvisibleTextColors(controller.document);
        controller.document = cleaned;
        final len = cleaned.length;
        controller.updateSelection(
          TextSelection(
            baseOffset: sel.baseOffset.clamp(0, len),
            extentOffset: sel.extentOffset.clamp(0, len),
          ),
          ChangeSource.local,
        );
      } finally {
        fixing = false;
      }
    }

    controller.addListener(sanitize);
    return controller.document.changes.listen((_) => sanitize());
  }

  /// Quill 편집용 컨트롤러 — 로드 시·입력 중 투명 글자색을 막는다.
  static QuillController createEditingController({
    required Document document,
    TextSelection selection = const TextSelection.collapsed(offset: 0),
  }) {
    final controller = QuillController(
      document: _documentWithoutInvisibleTextColors(document),
      selection: selection,
    );
    attachInvisibleColorGuard(controller);
    return controller;
  }

  static List<WorkerAnnouncementBlock> blocksForApi(Document doc) {
    if (documentHasLocalImages(doc)) {
      throw StateError(
        '로컬 이미지가 아직 업로드되지 않았습니다. '
        '저장 전 prepareDocumentForSave 또는 uploadLocalImagesInDocument를 호출하세요.',
      );
    }
    return [encodeDocument(doc)];
  }

  /// 로컬 파일 경로·`file://` 참조인지 (아직 서버에 안 올린 이미지).
  static bool isLocalImageRef(String ref) {
    final u = ref.trim();
    if (u.isEmpty) return false;
    final lower = u.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return false;
    }
    if (lower.startsWith('file://')) return true;
    if (u.startsWith('/')) return true;
    if (!kIsWeb && RegExp(r'^[A-Za-z]:\\').hasMatch(u)) return true;
    return false;
  }

  static String localPathFromRef(String ref) {
    final u = ref.trim();
    if (u.startsWith('file://')) {
      return Uri.parse(u).toFilePath();
    }
    return u;
  }

  static bool documentHasLocalImages(Document doc) {
    for (final op in doc.toDelta().operations) {
      final data = op.data;
      if (data is! Map) continue;
      if (data.containsKey('image')) {
        if (isLocalImageRef(data['image']?.toString() ?? '')) return true;
      }
      final stripRaw = data[AnnouncementImageStripEmbed.type];
      if (stripRaw == null) continue;
      final stripJson = stripRaw is String ? stripRaw : jsonEncode(stripRaw);
      final parsed = AnnouncementImageStripData.tryParseJson(stripJson);
      if (parsed == null) continue;
      for (final u in parsed.urls) {
        if (isLocalImageRef(u)) return true;
      }
    }
    return false;
  }

  /// 저장 직전 — 문서 안 로컬 이미지를 업로드하고 URL로 치환한다.
  static Future<Document> uploadLocalImagesInDocument(
    Document doc, {
    ImageUploadCategory category = ImageUploadCategory.announcementImage,
    void Function(int current, int total)? onProgress,
  }) async {
    final ops = List<dynamic>.from(doc.toDelta().toJson());
    final locals = <String>{};

    void collect(String raw) {
      final u = raw.trim();
      if (isLocalImageRef(u)) locals.add(u);
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final ins = op['insert'];
      if (ins is! Map) continue;
      if (ins.containsKey('image')) {
        collect(ins['image']?.toString() ?? '');
      }
      final stripRaw = ins[AnnouncementImageStripEmbed.type];
      if (stripRaw == null) continue;
      final stripJson = stripRaw is String ? stripRaw : jsonEncode(stripRaw);
      final parsed = AnnouncementImageStripData.tryParseJson(stripJson);
      if (parsed == null) continue;
      for (final u in parsed.urls) {
        collect(u);
      }
    }

    if (locals.isEmpty) return doc;

    final urlByLocal = <String, String>{};
    final list = locals.toList(growable: false);
    for (var i = 0; i < list.length; i++) {
      onProgress?.call(i + 1, list.length);
      final ref = list[i];
      final res = await uploadLocalImageFile(
        localPathFromRef(ref),
        category: category,
      );
      urlByLocal[ref] = res.displayUrl;
    }

    final newOps = ops.map((op) {
      if (op is! Map) return op;
      final m = Map<String, dynamic>.from(op);
      final ins = m['insert'];
      if (ins is! Map) return m;
      final insM = Map<String, dynamic>.from(ins);
      if (insM.containsKey('image')) {
        final raw = insM['image']?.toString().trim() ?? '';
        final remote = urlByLocal[raw];
        if (remote != null) insM['image'] = remote;
      }
      final stripRaw = insM[AnnouncementImageStripEmbed.type];
      if (stripRaw != null) {
        final stripJson = stripRaw is String ? stripRaw : jsonEncode(stripRaw);
        final parsed = AnnouncementImageStripData.tryParseJson(stripJson);
        if (parsed != null) {
          final newUrls = parsed.urls
              .map((u) => urlByLocal[u.trim()] ?? u)
              .toList(growable: false);
          insM[AnnouncementImageStripEmbed.type] = jsonEncode(<String, Object?>{
            'urls': newUrls,
            'mode': parsed.mode.name,
          });
        }
      }
      m['insert'] = insM;
      return m;
    }).toList();

    return Document.fromDelta(Delta.fromJson(newOps));
  }

  /// 공지 수정 화면에 올 초기 문서.
  static Document documentForEditing(WorkerAnnouncementRead? existing) {
    if (existing == null || existing.blocks.isEmpty) {
      return Document();
    }
    return decodeToDocument(existing.blocks);
  }

  static Document legacyBlocksToDocument(List<WorkerAnnouncementBlock> blocks) {
    final delta = Delta();
    var any = false;
    for (final b in blocks) {
      switch (b) {
        case WorkerAnnouncementTextBlock(:final text):
          final t = text.trim();
          if (t.isEmpty || isQuillEnvelopeText(text)) continue;
          delta.insert('$t\n');
          any = true;
        case WorkerAnnouncementImageBlock(:final url):
          final u = url.trim();
          if (u.isEmpty) continue;
          delta.insert(BlockEmbed.image(u));
          delta.insert('\n');
          any = true;
      }
    }
    if (!any) {
      delta.insert('\n');
    }
    return Document.fromDelta(delta);
  }

  /// 비어 있는지 (공백·줄바꿈만인 텍스트 제외). 임베드(이미지 등)가 있으면 false.
  static bool deltaLooksEmpty(Document doc) {
    for (final op in doc.toDelta().operations) {
      final data = op.data;
      if (data is String) {
        if (data.replaceAll(RegExp(r'\s'), '').isNotEmpty) return false;
      } else {
        return false;
      }
    }
    return true;
  }

  /// 목록 미리보기용 — blocks에 표시 가능한 본문이 있는지.
  static bool blocksHaveDisplayableBody(List<WorkerAnnouncementBlock> blocks) {
    if (blocks.isEmpty) return false;
    if (blocksPlainTextPreview(blocks, maxLen: 1).isNotEmpty) return true;
    for (final b in blocks) {
      switch (b) {
        case WorkerAnnouncementImageBlock(:final url):
          if (url.trim().isNotEmpty) return true;
        case WorkerAnnouncementTextBlock(:final text):
          if (blocksLookLikeStoredQuill([b])) return true;
          if (text.trim().isNotEmpty) return true;
      }
    }
    return false;
  }

  static String _photoPreviewTag({int count = 1}) {
    if (count <= 0) return '[사진]';
    if (count == 1) return '[사진]';
    return '[사진 $count]';
  }

  static String _truncatePreview(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }

  static void _appendPreviewToken(StringBuffer buf, String token) {
    if (buf.isEmpty) {
      buf.write(token);
      return;
    }
    final tail = buf.toString();
    if (!RegExp(r'[\s]$').hasMatch(tail)) {
      buf.write(' ');
    }
    buf.write(token);
  }

  static String _normalizePreviewWhitespace(String s) {
    return s
        .replaceAll('\u200b', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
  }

  static String _deltaOpsOrderedPreview(List<dynamic> ops) {
    final buf = StringBuffer();
    for (final op in ops) {
      if (op is! Map) continue;
      final ins = op['insert'];
      if (ins is String) {
        buf.write(ins);
        continue;
      }
      if (ins is! Map) continue;

      if (ins.containsKey('image')) {
        final u = ins['image']?.toString().trim() ?? '';
        if (u.isNotEmpty) {
          _appendPreviewToken(buf, _photoPreviewTag());
        }
        continue;
      }

      final stripRaw = ins[AnnouncementImageStripEmbed.type];
      if (stripRaw == null) continue;
      final data = AnnouncementImageStripData.tryParseJson(
        stripRaw is String ? stripRaw : jsonEncode(stripRaw),
      );
      if (data != null && data.urls.isNotEmpty) {
        _appendPreviewToken(
          buf,
          _photoPreviewTag(count: data.urls.length),
        );
      } else {
        _appendPreviewToken(buf, _photoPreviewTag());
      }
    }
    return _normalizePreviewWhitespace(buf.toString());
  }

  static String _legacyBlocksOrderedPreview(
      List<WorkerAnnouncementBlock> blocks) {
    final buf = StringBuffer();
    for (final b in blocks) {
      switch (b) {
        case WorkerAnnouncementTextBlock(:final text):
          if (WorkerAnnouncementQuillCodec.isQuillEnvelopeText(text)) {
            final ops = decodeDeltaOps([b]);
            if (ops != null) {
              buf.write(_deltaOpsOrderedPreview(ops));
            }
            continue;
          }
          final t = text.trim();
          if (t.isNotEmpty) buf.write(t);
        case WorkerAnnouncementImageBlock(:final url):
          if (url.trim().isNotEmpty) {
            _appendPreviewToken(buf, _photoPreviewTag());
          }
      }
    }
    return _normalizePreviewWhitespace(buf.toString());
  }

  /// 수신함·목록 한 줄 미리보기 (Quill·레거시 공통, 본문 순서 유지).
  static String blocksPlainTextPreview(
    List<WorkerAnnouncementBlock> blocks, {
    int maxLen = 92,
  }) {
    if (blocks.isEmpty) return '';
    try {
      final ops = decodeDeltaOps(blocks);
      final ordered = ops != null
          ? _deltaOpsOrderedPreview(ops)
          : _legacyBlocksOrderedPreview(blocks);
      if (ordered.isEmpty) return '';
      return _truncatePreview(ordered, maxLen);
    } catch (_) {
      final fallback = _legacyBlocksOrderedPreview(blocks);
      if (fallback.isEmpty) return '';
      return _truncatePreview(fallback, maxLen);
    }
  }
}
