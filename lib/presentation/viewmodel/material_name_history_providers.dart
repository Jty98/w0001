import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/material_name_history_storage.dart';

final materialNameHistoryStorageProvider = Provider<MaterialNameHistoryStorage>(
  (ref) => MaterialNameHistoryStorage(),
);

final materialNameHistoryProvider = AsyncNotifierProvider<
    MaterialNameHistoryNotifier, Map<String, List<String>>>(
  MaterialNameHistoryNotifier.new,
);

class MaterialNameHistoryNotifier
    extends AsyncNotifier<Map<String, List<String>>> {
  MaterialNameHistoryStorage get _storage =>
      ref.read(materialNameHistoryStorageProvider);

  @override
  Future<Map<String, List<String>>> build() => _storage.readAll();

  List<String> namesForCategory(String? category) {
    final cat = category?.trim();
    if (cat == null || cat.isEmpty) return const [];
    return List<String>.from(state.value?[cat] ?? const []);
  }

  Future<void> remember(String category, String name) async {
    await _storage.remember(category: category, name: name);
    state = AsyncData(await _storage.readAll());
  }

  Future<void> remove(String category, String name) async {
    await _storage.remove(category: category, name: name);
    state = AsyncData(await _storage.readAll());
  }
}
