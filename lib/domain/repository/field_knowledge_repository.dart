import 'package:w0001/data/model/field_knowledge_models.dart';

/// 현장 지식 사전 Repository 인터페이스
abstract class FieldKnowledgeRepository {
  /// 항목 리스트 조회 (페이지네이션, 검색, 필터)
  Future<KnowledgePage> getEntries({
    KnowledgeFilter filter = const KnowledgeFilter(),
    int page = 1,
    int pageSize = 20,
  });

  /// 단일 항목 조회 (조회수 증가)
  Future<KnowledgeEntry?> getEntry(int id);

  /// 항목 생성
  Future<KnowledgeEntry> createEntry(KnowledgeEntry entry);

  /// 항목 수정
  Future<KnowledgeEntry> updateEntry(KnowledgeEntry entry);

  /// 항목 삭제
  Future<bool> deleteEntry(int id);

  /// 태그 목록 (자동완성용)
  Future<List<KnowledgeTagStats>> getTags({
    KnowledgeEntryType? type,
    String? query,
  });

  /// 연관 항목 조회 (상세 화면에서 "관련 자료" 표시)
  Future<List<KnowledgeEntry>> getRelatedEntries(int id, {int limit = 5});
}
