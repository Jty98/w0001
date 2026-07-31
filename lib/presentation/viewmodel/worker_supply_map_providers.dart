import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/worker_supply_map_preferences_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/kakao_local_map_api.dart';
import 'package:w0001/data/datasources/remote/worker/worker_supply_places_source.dart';

enum WorkerSupplyCategory {
  hardware('철물점', 'hardware', '철물점', Icons.hardware_outlined),
  gasStation(
    '주유소',
    'gas_station',
    '주유소',
    Icons.local_gas_station_outlined,
  ),
  restaurant('음식점', 'restaurant', '음식점', Icons.restaurant_outlined),
  convenienceStore(
    '편의점',
    'convenience_store',
    '편의점',
    Icons.storefront_outlined,
  ),
  cafe(
    '카페',
    'cafe',
    '카페',
    Icons.local_cafe_outlined,
  ),
  parkingLot(
    '주차장',
    'parking_lot',
    '주차장',
    Icons.local_parking_outlined,
  ),
  evCharger(
    '충전소',
    'ev_charger',
    '전기차 충전소',
    Icons.ev_station_outlined,
  );

  const WorkerSupplyCategory(
    this.label,
    this.serverKey,
    this.keyword,
    this.icon,
  );

  final String label;
  final String serverKey;
  final String keyword;
  final IconData icon;

  static WorkerSupplyCategory? fromServerKey(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final category in WorkerSupplyCategory.values) {
      if (category.serverKey == normalized) return category;
    }
    return null;
  }
}

final kakaoLocalMapApiProvider = Provider<KakaoLocalMapApi>(
  (ref) => KakaoLocalMapApi(),
);

enum WorkerSupplyBackend { kakao, server }

final workerSupplyBackendProvider = Provider<WorkerSupplyBackend>((ref) {
  final raw =
      (dotenv.env['worker_supply_backend'] ?? 'server').trim().toLowerCase();
  return raw == 'server'
      ? WorkerSupplyBackend.server
      : WorkerSupplyBackend.kakao;
});

final workerSupplyPlacesSourceProvider = Provider<WorkerSupplyPlacesSource>((
  ref,
) {
  final backend = ref.watch(workerSupplyBackendProvider);
  if (backend == WorkerSupplyBackend.server) {
    return WorkerSupplyPlacesServerSource(AppHttpClient.I);
  }
  return WorkerSupplyPlacesKakaoSource(ref.watch(kakaoLocalMapApiProvider));
});

class WorkerSupplyCategoryNotifier extends Notifier<WorkerSupplyCategory> {
  @override
  WorkerSupplyCategory build() => WorkerSupplyCategory.hardware;

  void setCategory(WorkerSupplyCategory value) {
    state = value;
  }
}

final workerSupplyCategoryProvider =
    NotifierProvider<WorkerSupplyCategoryNotifier, WorkerSupplyCategory>(
  WorkerSupplyCategoryNotifier.new,
);

class WorkerSupplySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value.trim();
  }
}

final workerSupplySearchQueryProvider =
    NotifierProvider<WorkerSupplySearchQueryNotifier, String>(
  WorkerSupplySearchQueryNotifier.new,
);

final workerSupplyMapPreferencesStorageProvider =
    Provider<WorkerSupplyMapPreferencesStorage>(
  (ref) => WorkerSupplyMapPreferencesStorage(),
);

class WorkerSupplyFuelPriceDisplayModeNotifier
    extends Notifier<WorkerSupplyFuelPriceDisplayMode> {
  @override
  WorkerSupplyFuelPriceDisplayMode build() {
    Future.microtask(_load);
    return WorkerSupplyFuelPriceDisplayMode.gasoline;
  }

  Future<void> _load() async {
    final storage = ref.read(workerSupplyMapPreferencesStorageProvider);
    final loaded = await storage.loadFuelDisplayMode();
    state = loaded;
  }

  Future<void> setMode(WorkerSupplyFuelPriceDisplayMode mode) async {
    state = mode;
    final storage = ref.read(workerSupplyMapPreferencesStorageProvider);
    await storage.saveFuelDisplayMode(mode);
  }
}

final workerSupplyFuelPriceDisplayModeProvider = NotifierProvider<
    WorkerSupplyFuelPriceDisplayModeNotifier, WorkerSupplyFuelPriceDisplayMode>(
  WorkerSupplyFuelPriceDisplayModeNotifier.new,
);
