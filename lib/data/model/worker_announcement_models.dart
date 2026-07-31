import 'dart:convert';

import 'package:w0001/data/model/remote/super_admin_json.dart';

/// Quill 본문 저장 접두사 — [WorkerAnnouncementQuillCodec]와 동일.
const kWorkerAnnouncementQuillMagic = '__W0001_QUILL_V1__:';

/// `global`: 가입 작업자 전원 / `place`: 해당 현장 접근 가능한 작업자만.
enum WorkerAnnouncementScope {
  global('global'),
  place('place');

  const WorkerAnnouncementScope(this.wireValue);

  final String wireValue;

  static WorkerAnnouncementScope parse(Object? raw) {
    final s = saString(raw)?.trim().toLowerCase() ?? '';
    return s == 'place'
        ? WorkerAnnouncementScope.place
        : WorkerAnnouncementScope.global;
  }
}

/// 공지 본문 한 덩어리 (텍스트 또는 이미지 URL).
sealed class WorkerAnnouncementBlock {
  const WorkerAnnouncementBlock();

  Map<String, dynamic> toJson();

  factory WorkerAnnouncementBlock.fromJson(Map<String, dynamic> m) {
    final t = (saString(m['type']) ?? '').toLowerCase().trim();
    switch (t) {
      case 'image':
      case 'img':
        final url = saString(m['url']) ?? saString(m['display_url']) ?? '';
        return WorkerAnnouncementImageBlock(url.isNotEmpty ? url : '');
      case 'text':
      default:
        final insert = m['insert'];
        if (insert != null) {
          return quillTextBlockFromDeltaOps([Map<String, dynamic>.from(m)]);
        }
        var text = saString(m['text']) ??
            saString(m['content']) ??
            saString(m['value']) ??
            '';
        text = _normalizeStoredQuillText(text);
        return WorkerAnnouncementTextBlock(text);
    }
  }
}

bool looksLikeDeltaOpMap(Map<dynamic, dynamic> m) => m.containsKey('insert');

bool looksLikeDeltaOpsList(List<dynamic> list) {
  for (final e in list) {
    if (e is Map && looksLikeDeltaOpMap(e)) return true;
  }
  return false;
}

WorkerAnnouncementTextBlock quillTextBlockFromDeltaOps(List<dynamic> ops) {
  return WorkerAnnouncementTextBlock(
    '$kWorkerAnnouncementQuillMagic${jsonEncode(ops)}',
  );
}

String _normalizeStoredQuillText(String text) {
  final t = text.trim();
  if (t.isEmpty) return '';
  if (t.startsWith(kWorkerAnnouncementQuillMagic)) return t;
  if (t.startsWith('[')) {
    try {
      final decoded = jsonDecode(t);
      if (decoded is List && looksLikeDeltaOpsList(decoded)) {
        return '$kWorkerAnnouncementQuillMagic$t';
      }
    } catch (_) {}
  }
  return t;
}

List<WorkerAnnouncementBlock> blocksFromDeltaPayload(Object? raw) {
  if (raw == null) return const [];
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final ops = map['ops'];
    if (ops is List && looksLikeDeltaOpsList(ops)) {
      return [quillTextBlockFromDeltaOps(ops)];
    }
    if (looksLikeDeltaOpMap(map)) {
      return [
        quillTextBlockFromDeltaOps([map])
      ];
    }
    return const [];
  }
  if (raw is List) {
    if (looksLikeDeltaOpsList(raw)) {
      return [quillTextBlockFromDeltaOps(raw)];
    }
    return const [];
  }
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    if (t.startsWith(kWorkerAnnouncementQuillMagic)) {
      return [WorkerAnnouncementTextBlock(t)];
    }
    try {
      final decoded = jsonDecode(t);
      if (decoded is List && looksLikeDeltaOpsList(decoded)) {
        return [quillTextBlockFromDeltaOps(decoded)];
      }
      if (decoded is Map) {
        final fromMap = blocksFromDeltaPayload(decoded);
        if (fromMap.isNotEmpty) return fromMap;
      }
    } catch (_) {
      return [WorkerAnnouncementTextBlock(t)];
    }
  }
  return const [];
}

final class WorkerAnnouncementTextBlock extends WorkerAnnouncementBlock {
  const WorkerAnnouncementTextBlock(this.text);

  final String text;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'text',
        'text': text,
      };
}

final class WorkerAnnouncementImageBlock extends WorkerAnnouncementBlock {
  const WorkerAnnouncementImageBlock(this.url);

  final String url;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'image',
        'url': url,
      };
}

class WorkerAnnouncementRead {
  const WorkerAnnouncementRead({
    required this.id,
    required this.scope,
    required this.title,
    required this.blocks,
    this.pid,
    this.placeName,
    this.placePcomplete,
    this.createdAt,
    this.updatedAt,
    this.isPinned = false,
  });

  final int id;
  final WorkerAnnouncementScope scope;
  final int? pid;
  final String? placeName;

  /// 응답에 포함된 현장 `pcomplete` (0=진행, 1=완료).
  final int? placePcomplete;
  final String title;
  final List<WorkerAnnouncementBlock> blocks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPinned;

  factory WorkerAnnouncementRead.fromJson(Map<String, dynamic> m) {
    final blocks = _parseBlocksFromJson(m);
    DateTime? parseDt(Object? v) {
      final s = saString(v)?.trim();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return WorkerAnnouncementRead(
      id: saInt(m['id']) ?? saInt(m['announcement_id']) ?? saInt(m['nid']) ?? 0,
      scope: WorkerAnnouncementScope.parse(m['scope'] ?? m['visibility']),
      pid: saInt(m['pid'] ?? m['place_id']),
      placeName: _parsePlaceName(m),
      placePcomplete: _parsePlacePcomplete(m),
      title: saString(m['title'])?.trim() ?? '',
      blocks: blocks,
      createdAt: parseDt(m['created_at'] ?? m['createdAt']),
      updatedAt: parseDt(m['updated_at'] ?? m['updatedAt']),
      isPinned: m['is_pinned'] == true ||
          m['isPinned'] == true ||
          m['pinned'] == true,
    );
  }

  bool get isGlobal => scope == WorkerAnnouncementScope.global;

  static int? _parsePlacePcomplete(Map<String, dynamic> m) {
    final direct = saInt(m['pcomplete'] ?? m['place_pcomplete']);
    if (direct == 0 || direct == 1) return direct;
    final place = m['place'];
    if (place is Map) {
      final nested = saInt(Map<String, dynamic>.from(place)['pcomplete']);
      if (nested == 0 || nested == 1) return nested;
    }
    return null;
  }

  static String? _parsePlaceName(Map<String, dynamic> m) {
    final direct =
        saString(m['pname'] ?? m['place_name'] ?? m['placeName'])?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final place = m['place'];
    if (place is Map) {
      final nested = saString(
        Map<String, dynamic>.from(place)['pname'] ??
            Map<String, dynamic>.from(place)['name'] ??
            Map<String, dynamic>.from(place)['place_name'],
      )?.trim();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return null;
  }

  static List<WorkerAnnouncementBlock> _parseBlocksFromJson(
    Map<String, dynamic> m,
  ) {
    for (final key in [
      'blocks',
      'body_blocks',
      'instruction_blocks',
      'content_blocks',
      'body_delta',
      'delta',
      'content_delta',
      'document',
    ]) {
      final fromDelta = blocksFromDeltaPayload(m[key]);
      if (fromDelta.isNotEmpty) return fromDelta;

      final fromBlocks = parseWorkerAnnouncementBlockList(m[key]);
      if (fromBlocks.isNotEmpty) return fromBlocks;
    }

    for (final key in ['body', 'content', 'text']) {
      final fromBody = blocksFromDeltaPayload(m[key]);
      if (fromBody.isNotEmpty) return fromBody;
      final fromBlocks = parseWorkerAnnouncementBlockList(m[key]);
      if (fromBlocks.isNotEmpty) return fromBlocks;
    }

    for (final key in [
      'body_preview',
      'preview',
      'preview_text',
      'summary',
      'excerpt',
      'plain_text',
    ]) {
      final s = saString(m[key])?.trim();
      if (s != null && s.isNotEmpty) {
        return [WorkerAnnouncementTextBlock(s)];
      }
    }

    return const [];
  }

  WorkerAnnouncementRead copyWith({
    int? id,
    WorkerAnnouncementScope? scope,
    int? pid,
    String? placeName,
    int? placePcomplete,
    String? title,
    List<WorkerAnnouncementBlock>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return WorkerAnnouncementRead(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      pid: pid ?? this.pid,
      placeName: placeName ?? this.placeName,
      placePcomplete: placePcomplete ?? this.placePcomplete,
      title: title ?? this.title,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

/// `instruction_blocks` 등 JSON 배열·문자열·Delta 맵에서 블록 목록 파싱.
List<WorkerAnnouncementBlock> parseWorkerAnnouncementBlockList(Object? raw) {
  if (raw == null) return const [];
  final fromDelta = blocksFromDeltaPayload(raw);
  if (fromDelta.isNotEmpty) return fromDelta;

  List<dynamic>? list;
  if (raw is List) {
    list = raw;
  } else if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    final fromDelta = blocksFromDeltaPayload(t);
    if (fromDelta.isNotEmpty) return fromDelta;
    try {
      final d = jsonDecode(t);
      if (d is List) list = d;
    } catch (_) {
      return [WorkerAnnouncementTextBlock(t)];
    }
  }
  if (list == null || list.isEmpty) return const [];
  if (looksLikeDeltaOpsList(list)) {
    return blocksFromDeltaPayload(list);
  }
  final out = <WorkerAnnouncementBlock>[];
  for (final e in list) {
    if (e is Map) {
      out.add(
        WorkerAnnouncementBlock.fromJson(Map<String, dynamic>.from(e)),
      );
    }
  }
  return out;
}

/// 관리자 생성·수정 요청 본문.
class WorkerAnnouncementWriteBody {
  const WorkerAnnouncementWriteBody({
    required this.scope,
    required this.title,
    required this.blocks,
    this.pid,
  });

  final WorkerAnnouncementScope scope;
  final int? pid;
  final String title;
  final List<WorkerAnnouncementBlock> blocks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scope': scope.wireValue,
      if (pid != null) 'pid': pid,
      'title': title.trim(),
      'blocks': blocks.map((e) => e.toJson()).toList(),
    };
  }
}
