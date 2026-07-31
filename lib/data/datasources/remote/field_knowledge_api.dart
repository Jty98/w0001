import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';

// uploadLocalImageFile과 ImageUploadCategory를 외부에서도 사용할 수 있도록 재export
export 'package:w0001/util/image_attachment/upload_image_remote.dart'
    show uploadLocalImageFile;
export 'package:w0001/util/image_attachment/image_upload_result.dart'
    show ImageUploadResult, ImageUploadCategory;

/// 현장 지식 사전 API 클라이언트
class FieldKnowledgeApi {
  const FieldKnowledgeApi(this._client);

  final AppHttpClient _client;

  static const String _basePath = '/extras/field-knowledge';

  /// 항목 리스트 조회
  Future<KnowledgePage> getEntries({
    required Map<String, dynamic> params,
  }) async {
    final response =
        await _client.get('$_basePath/entries', queryParameters: params);
    return KnowledgePage.fromJson(response.data as Map<String, dynamic>);
  }

  /// 단일 항목 조회
  Future<KnowledgeEntry?> getEntry(int id) async {
    try {
      final response = await _client.get('$_basePath/entries/$id');
      return KnowledgeEntry.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// 항목 생성
  Future<KnowledgeEntry> createEntry(KnowledgeEntry entry) async {
    final response = await _client.post(
      '$_basePath/entries',
      data: entry.toWriteJson(),
    );
    return KnowledgeEntry.fromJson(response.data as Map<String, dynamic>);
  }

  /// 항목 수정 (PATCH - 부분 수정)
  Future<KnowledgeEntry> updateEntry(KnowledgeEntry entry) async {
    final response = await _client.patch(
      '$_basePath/entries/${entry.id}',
      data: entry.toWriteJson(),
    );
    return KnowledgeEntry.fromJson(response.data as Map<String, dynamic>);
  }

  /// 항목 삭제
  Future<void> deleteEntry(int id) async {
    await _client.delete('$_basePath/entries/$id');
  }

  /// 태그 목록
  Future<List<KnowledgeTagStats>> getTags({
    String? type,
    String? query,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (type != null) params['type'] = type;
    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }

    final response =
        await _client.get('$_basePath/tags', queryParameters: params);
    final data = response.data;

    // 서버 응답 구조 확인
    final items =
        data is Map && data.containsKey('items') ? data['items'] : data;

    if (items is! List) return const [];
    return items
        .map((e) => KnowledgeTagStats.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 연관 항목 (상세 조회 응답에 포함되므로 선택적 사용)
  Future<List<KnowledgeEntry>> getRelatedEntries(int id,
      {int limit = 5}) async {
    final response = await _client.get(
      '$_basePath/entries/$id/related',
      queryParameters: {'limit': limit},
    );
    final data = response.data;

    // 서버 응답 구조 확인
    final items =
        data is Map && data.containsKey('items') ? data['items'] : data;

    if (items is! List) return const [];
    return items
        .map((e) => KnowledgeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 이미지 업로드 (기존 uploads/image API 사용)
  /// 반환: 업로드된 이미지 URL
  Future<String> uploadImage(String filePath) async {
    // 기존 image_attachment 시스템 사용
    final result = await uploadLocalImageFile(
      filePath,
      category: ImageUploadCategory.placeImage,
    );
    return result.displayUrl;
  }
}
