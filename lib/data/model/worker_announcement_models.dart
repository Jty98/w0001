import 'dart:convert';

import 'package:w0001/data/model/remote/super_admin_json.dart';

/// `global`: 가입 작업자 전원 / `place`: 해당 현장 접근 가능한 작업자만.
enum WorkerAnnouncementScope {
  global('global'),
  place('place');

  const WorkerAnnouncementScope(this.wireValue);

  final String wireValue;

  static WorkerAnnouncementScope parse(Object? raw) {
    final s = saString(raw)?.trim().toLowerCase() ?? '';
    return s == 'place' ? WorkerAnnouncementScope.place : WorkerAnnouncementScope.global;
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
        return WorkerAnnouncementTextBlock(saString(m['text']) ?? '');
    }
  }
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
    this.createdAt,
    this.updatedAt,
    this.isPinned = false,
  });

  final int id;
  final WorkerAnnouncementScope scope;
  final int? pid;
  final String title;
  final List<WorkerAnnouncementBlock> blocks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPinned;

  factory WorkerAnnouncementRead.fromJson(Map<String, dynamic> m) {
    final blocks = parseWorkerAnnouncementBlockList(m['blocks'] ?? m['body_blocks']);
    DateTime? parseDt(Object? v) {
      final s = saString(v)?.trim();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return WorkerAnnouncementRead(
      id: saInt(m['id']) ??
          saInt(m['announcement_id']) ??
          saInt(m['nid']) ??
          0,
      scope: WorkerAnnouncementScope.parse(m['scope'] ?? m['visibility']),
      pid: saInt(m['pid'] ?? m['place_id']),
      title: saString(m['title'])?.trim() ?? '',
      blocks: blocks,
      createdAt: parseDt(m['created_at'] ?? m['createdAt']),
      updatedAt: parseDt(m['updated_at'] ?? m['updatedAt']),
      isPinned: m['is_pinned'] == true || m['isPinned'] == true || m['pinned'] == true,
    );
  }

  bool get isGlobal => scope == WorkerAnnouncementScope.global;
  
  WorkerAnnouncementRead copyWith({
    int? id,
    WorkerAnnouncementScope? scope,
    int? pid,
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
      title: title ?? this.title,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

/// `instruction_blocks` 등 JSON 배열·문자열에서 블록 목록 파싱.
List<WorkerAnnouncementBlock> parseWorkerAnnouncementBlockList(Object? raw) {
  List<dynamic>? list;
  if (raw == null) return const [];
  if (raw is List) {
    list = raw;
  } else if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    try {
      final d = jsonDecode(t);
      if (d is List) list = d;
    } catch (_) {
      return const [];
    }
  }
  if (list == null || list.isEmpty) return const [];
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
