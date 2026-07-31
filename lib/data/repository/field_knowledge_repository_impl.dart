import 'package:w0001/data/datasources/remote/field_knowledge_api.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/domain/repository/field_knowledge_repository.dart';

class FieldKnowledgeRepositoryImpl implements FieldKnowledgeRepository {
  const FieldKnowledgeRepositoryImpl(this._api);

  final FieldKnowledgeApi _api;

  @override
  Future<KnowledgePage> getEntries({
    KnowledgeFilter filter = const KnowledgeFilter(),
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = filter.toQueryParams(page: page, pageSize: pageSize);
    return await _api.getEntries(params: params);
  }

  @override
  Future<KnowledgeEntry?> getEntry(int id) async {
    return await _api.getEntry(id);
  }

  @override
  Future<KnowledgeEntry> createEntry(KnowledgeEntry entry) async {
    return await _api.createEntry(entry);
  }

  @override
  Future<KnowledgeEntry> updateEntry(KnowledgeEntry entry) async {
    return await _api.updateEntry(entry);
  }

  @override
  Future<bool> deleteEntry(int id) async {
    try {
      await _api.deleteEntry(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<KnowledgeTagStats>> getTags({
    KnowledgeEntryType? type,
    String? query,
  }) async {
    return await _api.getTags(
      type: type?.value,
      query: query,
    );
  }

  @override
  Future<List<KnowledgeEntry>> getRelatedEntries(
    int id, {
    int limit = 5,
  }) async {
    return await _api.getRelatedEntries(id, limit: limit);
  }
}
