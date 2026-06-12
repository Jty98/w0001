import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';

/// 서버 변경 전까지 Quill 문서(JSON ops)를 한 개의 텍스트 블록에 싣습니다.
abstract final class WorkerAnnouncementQuillCodec {
  WorkerAnnouncementQuillCodec._();

  static const magic = '__W0001_QUILL_V1__:';

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
    final b = blocks.first as WorkerAnnouncementTextBlock;
    final raw =
        jsonDecode(b.text.substring(b.text.indexOf(magic) + magic.length));
    if (raw is List) return raw;
    if (raw is Map<String, dynamic> && raw['ops'] is List) {
      return raw['ops'] as List<dynamic>;
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

  static List<WorkerAnnouncementBlock> blocksForApi(Document doc) {
    return [encodeDocument(doc)];
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

  /// 수신함·목록 한 줄 미리보기 (Quill·레거시 공통 디코드).
  static String blocksPlainTextPreview(
    List<WorkerAnnouncementBlock> blocks, {
    int maxLen = 92,
  }) {
    if (blocks.isEmpty) return '';
    try {
      final doc = decodeToDocument(blocks);
      final buf = StringBuffer();
      var hasNonText = false;
      for (final op in doc.toDelta().operations) {
        final data = op.data;
        if (data is String) {
          buf.write(data);
        } else {
          hasNonText = true;
        }
      }
      var s = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.isEmpty) {
        return hasNonText ? '사진·첨부 포함' : '';
      }
      if (s.length > maxLen) {
        return '${s.substring(0, maxLen)}…';
      }
      return s;
    } catch (_) {
      return '';
    }
  }
}
