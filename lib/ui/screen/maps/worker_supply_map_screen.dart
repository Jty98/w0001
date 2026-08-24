import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/worker/worker_supply_places_source.dart';
import 'package:w0001/data/datasources/local/worker_supply_map_preferences_storage.dart';
import 'package:w0001/data/model/worker_supply_place.dart';
import 'package:w0001/presentation/viewmodel/worker_supply_map_providers.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/map_route_action_buttons.dart';
import 'package:w0001/util/map_navigation_launcher.dart';
import 'package:w0001/util/responsive_layout.dart';

typedef _WorkerSupplyFetchResult = ({
  Map<WorkerSupplyCategory, List<WorkerSupplyPlace>> rowsByCategory,
  List<WorkerSupplyCluster> clusters,
  WorkerSupplyResponseKind responseKind,
  List<String> errors,
  String? nextCursor,
  int? nextCursorTtlSeconds,
});

class _CachedWorkerSupplyFetchResult {
  const _CachedWorkerSupplyFetchResult({
    required this.savedAt,
    required this.result,
  });

  final DateTime savedAt;
  final _WorkerSupplyFetchResult result;
}

class _WorkerSupplyCategorySection {
  const _WorkerSupplyCategorySection({
    required this.category,
    required this.places,
  });

  final WorkerSupplyCategory category;
  final List<WorkerSupplyPlace> places;
}

class WorkerSupplyMapScreen extends ConsumerStatefulWidget {
  const WorkerSupplyMapScreen({super.key});

  @override
  ConsumerState<WorkerSupplyMapScreen> createState() =>
      _WorkerSupplyMapScreenState();
}

class _WorkerSupplyMapScreenState extends ConsumerState<WorkerSupplyMapScreen> {
  static final LatLng _fallbackCenter = LatLng(37.5665, 126.9780);
  static const String _myLocationMarkerId = '__my_location__';
  static final String _myLocationDotMarkerImageSrc =
      'data:image/svg+xml;utf8,${Uri.encodeComponent('''
<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26">
  <circle cx="13" cy="13" r="10" fill="#2E7DFF" fill-opacity="0.28"/>
  <circle cx="13" cy="13" r="6.8" fill="#2E7DFF" stroke="#FFFFFF" stroke-width="2"/>
</svg>
''')}';

  KakaoMapController? _mapController;
  var _mapReady = false;
  var _pendingCenterOnMapReady = false;
  LatLng _mapCenter = _fallbackCenter;
  LatLng? _myLocationCenter;
  WorkerSupplyCategory? _selectedCategory;
  WorkerSupplyPlace? _sheetSelectedPlace;
  WorkerSupplyCategory? _sheetSelectedCategory;
  ScrollController? _resultsSheetScrollController;
  double _listSheetScrollOffset = 0;
  bool _pendingListScrollRestore = false;
  bool _listScrollRestoreScheduled = false;
  LatLngBounds? _currentBounds;
  List<WorkerSupplyPlace> _places = const [];
  List<WorkerSupplyCluster> _clusters = const [];
  Map<WorkerSupplyCategory, List<WorkerSupplyPlace>> _placesByCategory = {
    for (final category in WorkerSupplyCategory.values) category: const [],
  };
  final Map<String, WorkerSupplyPlace> _markerPlaceById =
      <String, WorkerSupplyPlace>{};
  final Map<String, WorkerSupplyCategory> _markerCategoryById =
      <String, WorkerSupplyCategory>{};
  String? _error;
  var _isLoading = false;
  var _showSearchInViewButton = false;
  var _hasLoadedOnce = false;
  final int _radiusMeters = 3000;
  var _sheetPointerCount = 0;
  var _mapDragLockedBySheet = false;
  var _currentMapLevel = 14;
  String? _nextCursor;
  bool _isLoadingMore = false;
  bool _lastSearchUsedBounds = false;
  LatLng? _lastNearbyCenter;
  LatLngBounds? _lastBounds;
  List<String> _lastCategories = const <String>[];
  String _lastSearchQuery = '';
  int? _nextCursorTtlSeconds;
  int _lastSearchMapLevel = 14;
  var _latestSearchRequestId = 0;
  final Map<String, _CachedWorkerSupplyFetchResult> _searchCache =
      <String, _CachedWorkerSupplyFetchResult>{};
  final Map<String, Future<_WorkerSupplyFetchResult>> _inflightSearches =
      <String, Future<_WorkerSupplyFetchResult>>{};
  static const Duration _searchCacheTtl = Duration(seconds: 45);
  static const int _searchCacheMaxEntries = 80;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromMyLocation(moveMap: true, fetchData: false);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _markerIdForPlace(
      WorkerSupplyCategory category, WorkerSupplyPlace place) {
    return '${category.serverKey}:${place.id}:${place.latitude}:${place.longitude}';
  }

  String _formatFuelPrice(num? value) {
    if (value == null) return '가격 정보 없음';
    return '${NumberFormat.decimalPattern('ko_KR').format(value.round())}원';
  }

  String _formatDistance(WorkerSupplyPlace place) {
    final meters = _distanceMetersFromMyLocation(place);
    if (meters == null) return '거리 정보 없음';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }

  double? _distanceMetersFromMyLocation(WorkerSupplyPlace place) {
    final origin = _myLocationCenter;
    if (origin == null) return null;
    if (place.latitude == 0 && place.longitude == 0) return null;
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      place.latitude,
      place.longitude,
    );
  }

  Color _categoryAccentColor(
      BuildContext context, WorkerSupplyCategory category) {
    final cs = Theme.of(context).colorScheme;
    switch (category) {
      case WorkerSupplyCategory.hardware:
        return cs.tertiary;
      case WorkerSupplyCategory.gasStation:
        return const Color(0xFF2E7DFF);
      case WorkerSupplyCategory.restaurant:
        return cs.primary;
      case WorkerSupplyCategory.convenienceStore:
        return const Color(0xFF2DBF64);
      case WorkerSupplyCategory.cafe:
        return const Color(0xFF8D6E63);
      case WorkerSupplyCategory.parkingLot:
        return const Color(0xFF546E7A);
      case WorkerSupplyCategory.evCharger:
        return const Color(0xFF00ACC1);
    }
  }

  bool _isGasCategory({
    WorkerSupplyCategory? category,
    required WorkerSupplyPlace place,
  }) {
    if (category == WorkerSupplyCategory.gasStation) return true;
    final serverCategory = place.category.trim().toLowerCase();
    if (serverCategory == WorkerSupplyCategory.gasStation.serverKey) {
      return true;
    }
    final raw = place.categoryName.trim().toLowerCase();
    return raw.contains('gas') || raw.contains('주유');
  }

  Widget _buildFuelSummaryForList(
    BuildContext context,
    WorkerSupplyPlace place,
    WorkerSupplyFuelPriceDisplayMode mode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final defaultStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    final emphasizedStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w900,
        );
    final gasolineStyle = mode == WorkerSupplyFuelPriceDisplayMode.gasoline
        ? emphasizedStyle
        : defaultStyle;
    final dieselStyle = mode == WorkerSupplyFuelPriceDisplayMode.diesel
        ? emphasizedStyle
        : defaultStyle;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '휘 ${_formatFuelPrice(place.gasolinePrice)}',
            style: gasolineStyle,
          ),
          TextSpan(text: ' / ', style: defaultStyle),
          TextSpan(
            text: '경 ${_formatFuelPrice(place.dieselPrice)}',
            style: dieselStyle,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _categoryPinColorHex(WorkerSupplyCategory category) {
    switch (category) {
      case WorkerSupplyCategory.hardware:
        return '6E4B3A';
      case WorkerSupplyCategory.gasStation:
        return '2E7DFF';
      case WorkerSupplyCategory.restaurant:
        return 'F45D48';
      case WorkerSupplyCategory.convenienceStore:
        return '2DBF64';
      case WorkerSupplyCategory.cafe:
        return '8D6E63';
      case WorkerSupplyCategory.parkingLot:
        return '546E7A';
      case WorkerSupplyCategory.evCharger:
        return '00ACC1';
    }
  }

  String _categoryPinInnerIconSvg(WorkerSupplyCategory category) {
    switch (category) {
      case WorkerSupplyCategory.hardware:
        return '<path d="M12.7 18.8l2.7 2.7 1.4-1.4-2.7-2.7zM16.6 15l3.7-3.7 1.5 1.5-3.7 3.7zM11.7 12.4l1.9 1.9M13.6 10.5l1.9 1.9" />';
      case WorkerSupplyCategory.gasStation:
        return '<path d="M13.2 20v-7a1 1 0 0 1 1-1h3.8a1 1 0 0 1 1 1v7M13.2 14.8h5.8M19 12.8l1.8 1.6v3.2a1 1 0 0 0 2 0v-2.2" />';
      case WorkerSupplyCategory.restaurant:
        return '<path d="M12.8 11.8v4.2M14.3 11.8v4.2M15.8 11.8v4.2M14.3 16v4M19 11.8v8.2M19 11.8c1 0 1.8.9 1.8 2v1.2h-1.8" />';
      case WorkerSupplyCategory.convenienceStore:
        return '<path d="M12.2 14.4h11.6M13 14.4l.8-2h7.8l.8 2M13.4 14.4V20h8.8v-5.6M16.2 20v-2.8h2.4V20" />';
      case WorkerSupplyCategory.cafe:
        return '<path d="M12.4 15.8h6.6a2 2 0 0 1 0 4h-6.6v-4zM13.4 14h4.6M12.2 21h9.2" />';
      case WorkerSupplyCategory.parkingLot:
        return '<path d="M13.5 20v-8h3.5a2.2 2.2 0 0 1 0 4.4h-3.5" />';
      case WorkerSupplyCategory.evCharger:
        return '<path d="M18.3 11.8l-3.3 4.4h2.4l-1 3.6 4-5h-2.4l.7-3zM12.6 20h2.2M21.2 20h2.2" />';
    }
  }

  String _categoryMarkerImageSrc(WorkerSupplyCategory category) {
    final hex = _categoryPinColorHex(category);
    final iconSvg = _categoryPinInnerIconSvg(category);
    return 'data:image/svg+xml;utf8,${Uri.encodeComponent('''
<svg xmlns="http://www.w3.org/2000/svg" width="36" height="44" viewBox="0 0 36 44">
  <defs>
    <filter id="s" x="-40%" y="-40%" width="180%" height="180%">
      <feDropShadow dx="0" dy="1.4" stdDeviation="1.2" flood-color="#000000" flood-opacity="0.22"/>
    </filter>
  </defs>
  <path filter="url(#s)" d="M18 1.2C9.82 1.2 3.2 7.82 3.2 16c0 10.2 11.2 22 13.83 24.63a1.38 1.38 0 0 0 1.95 0C21.6 38 32.8 26.2 32.8 16c0-8.18-6.62-14.8-14.8-14.8z" fill="#$hex" stroke="#FFFFFF" stroke-width="2"/>
  <circle cx="18" cy="16" r="8.3" fill="#FFFFFF"/>
  <g fill="none" stroke="#111827" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">$iconSvg</g>
</svg>
''')}';
  }

  bool _hasSearchContext(WorkerSupplyCategory? selectedCategory) {
    return selectedCategory != null;
  }

  bool _isSearchInViewEligible(WorkerSupplyCategory? selectedCategory) {
    if (!_hasLoadedOnce || _isLoading) return false;
    if (_currentBounds == null) return false;
    return _hasSearchContext(selectedCategory);
  }

  bool _hasMapMovedEnoughFromLastSearch() {
    if (!_hasLoadedOnce) return false;
    if (_lastSearchUsedBounds) {
      final previousBounds = _lastBounds;
      final currentBounds = _currentBounds;
      if (previousBounds == null || currentBounds == null) return false;
      final prevSw = previousBounds.getSouthWest();
      final prevNe = previousBounds.getNorthEast();
      final nowSw = currentBounds.getSouthWest();
      final nowNe = currentBounds.getNorthEast();
      final prevCenter = LatLng(
        (prevSw.latitude + prevNe.latitude) / 2,
        (prevSw.longitude + prevNe.longitude) / 2,
      );
      final nowCenter = LatLng(
        (nowSw.latitude + nowNe.latitude) / 2,
        (nowSw.longitude + nowNe.longitude) / 2,
      );
      final movedMeters = Geolocator.distanceBetween(
        prevCenter.latitude,
        prevCenter.longitude,
        nowCenter.latitude,
        nowCenter.longitude,
      );
      return movedMeters >= 180 ||
          (_currentMapLevel - _lastSearchMapLevel).abs() >= 1;
    }
    final previousCenter = _lastNearbyCenter;
    if (previousCenter == null) return false;
    final movedMeters = Geolocator.distanceBetween(
      previousCenter.latitude,
      previousCenter.longitude,
      _mapCenter.latitude,
      _mapCenter.longitude,
    );
    return movedMeters >= 140 ||
        (_currentMapLevel - _lastSearchMapLevel).abs() >= 1;
  }

  int _serverMapLevelForBounds(int kakaoLevel) {
    // Kakao level is lower when zoomed in (1 close, 14 far),
    // while backend map_level is higher when zoomed in.
    return (15 - kakaoLevel).clamp(1, 14);
  }

  List<WorkerSupplyPlace> _sortedByDistance(List<WorkerSupplyPlace> rows) {
    final sorted = List<WorkerSupplyPlace>.from(rows);
    sorted.sort((a, b) {
      final da = _distanceMetersFromMyLocation(a);
      final db = _distanceMetersFromMyLocation(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return sorted;
  }

  void _setPlacesByCategory(
    Map<WorkerSupplyCategory, List<WorkerSupplyPlace>> byCategory,
  ) {
    final normalized = <WorkerSupplyCategory, List<WorkerSupplyPlace>>{
      for (final category in WorkerSupplyCategory.values)
        category: _sortedByDistance(byCategory[category] ?? const []),
    };
    final markerMap = <String, WorkerSupplyPlace>{};
    final markerCategoryMap = <String, WorkerSupplyCategory>{};
    final merged = <WorkerSupplyPlace>[];
    final seen = <String>{};

    for (final category in WorkerSupplyCategory.values) {
      final rows = normalized[category] ?? const [];
      for (final place in rows) {
        final markerId = _markerIdForPlace(category, place);
        markerMap[markerId] = place;
        markerCategoryMap[markerId] = category;
        final dedupeKey = '${category.serverKey}:${place.id}';
        if (seen.add(dedupeKey)) {
          merged.add(place);
        }
      }
    }

    _markerPlaceById
      ..clear()
      ..addAll(markerMap);
    _markerCategoryById
      ..clear()
      ..addAll(markerCategoryMap);

    _placesByCategory = normalized;
    _places = merged;
  }

  void _appendPlacesByCategory(
    Map<WorkerSupplyCategory, List<WorkerSupplyPlace>> byCategory,
  ) {
    final merged = <WorkerSupplyCategory, List<WorkerSupplyPlace>>{
      for (final category in WorkerSupplyCategory.values)
        category: List<WorkerSupplyPlace>.from(
            _placesByCategory[category] ?? const []),
    };
    for (final category in WorkerSupplyCategory.values) {
      final current = merged[category]!;
      final existingKeys =
          current.map((e) => '${e.id}:${e.latitude}:${e.longitude}').toSet();
      final incoming = byCategory[category] ?? const <WorkerSupplyPlace>[];
      for (final place in incoming) {
        final key = '${place.id}:${place.latitude}:${place.longitude}';
        if (existingKeys.add(key)) {
          current.add(place);
        }
      }
    }
    _setPlacesByCategory(merged);
  }

  String _normalizedQuery(String value) => value.trim().toLowerCase();

  String _roundedCoord(double value) => value.toStringAsFixed(4);

  WorkerSupplyServerSort _serverSortMode() => WorkerSupplyServerSort.distance;

  String _buildNearbyCacheKey({
    required List<String> categoryServerKeys,
    required String searchQuery,
    required LatLng center,
  }) {
    final mode = _normalizedQuery(searchQuery).isEmpty ? 'category' : 'query';
    final categoryKey = categoryServerKeys.toSet().toList(growable: false)
      ..sort();
    return [
      'nearby',
      mode,
      categoryKey.join(','),
      _normalizedQuery(searchQuery),
      _roundedCoord(center.latitude),
      _roundedCoord(center.longitude),
      'r$_radiusMeters',
    ].join('|');
  }

  String _buildBoundsCacheKey({
    required List<String> categoryServerKeys,
    required String searchQuery,
    required LatLng sw,
    required LatLng ne,
    required int? mapLevel,
  }) {
    final mode = _normalizedQuery(searchQuery).isEmpty ? 'category' : 'query';
    final categoryKey = categoryServerKeys.toSet().toList(growable: false)
      ..sort();
    return [
      'in_bounds',
      mode,
      categoryKey.join(','),
      _normalizedQuery(searchQuery),
      _roundedCoord(sw.latitude),
      _roundedCoord(sw.longitude),
      _roundedCoord(ne.latitude),
      _roundedCoord(ne.longitude),
      'lvl${mapLevel ?? -1}',
      'cluster:false',
    ].join('|');
  }

  void _pruneSearchCache() {
    final now = DateTime.now();
    _searchCache
        .removeWhere((_, row) => now.difference(row.savedAt) > _searchCacheTtl);
    final overflow = _searchCache.length - _searchCacheMaxEntries;
    if (overflow <= 0) return;
    final oldestKeys = _searchCache.keys.take(overflow).toList(growable: false);
    for (final key in oldestKeys) {
      _searchCache.remove(key);
    }
  }

  bool _isCacheFresh(_CachedWorkerSupplyFetchResult cached) {
    return DateTime.now().difference(cached.savedAt) <= _searchCacheTtl;
  }

  Future<_WorkerSupplyFetchResult> _requestWithCache({
    required String cacheKey,
    required Future<_WorkerSupplyFetchResult> Function() requestBuilder,
  }) async {
    _pruneSearchCache();
    final cached = _searchCache[cacheKey];
    if (cached != null && _isCacheFresh(cached)) {
      return cached.result;
    }
    final inflight = _inflightSearches[cacheKey];
    if (inflight != null) {
      return inflight;
    }
    final future = Future<_WorkerSupplyFetchResult>.sync(requestBuilder);
    _inflightSearches[cacheKey] = future;
    try {
      final result = await future;
      _searchCache[cacheKey] = _CachedWorkerSupplyFetchResult(
        savedAt: DateTime.now(),
        result: result,
      );
      _pruneSearchCache();
      return result;
    } finally {
      _inflightSearches.remove(cacheKey);
    }
  }

  List<String> _categoriesForRequest({
    required bool integrated,
    required WorkerSupplyCategory? selectedCategory,
  }) {
    if (integrated) {
      return WorkerSupplyCategory.values
          .map((category) => category.serverKey)
          .toList(growable: false);
    }
    if (selectedCategory == null) return const <String>[];
    return <String>[selectedCategory.serverKey];
  }

  WorkerSupplyCategory? _fallbackCategoryFromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('gas') || normalized.contains('주유')) {
      return WorkerSupplyCategory.gasStation;
    }
    if (normalized.contains('편의점') ||
        normalized.contains('convenience') ||
        normalized.contains('cu') ||
        normalized.contains('gs25') ||
        normalized.contains('세븐일레븐')) {
      return WorkerSupplyCategory.convenienceStore;
    }
    if (normalized.contains('restaurant') || normalized.contains('음식')) {
      return WorkerSupplyCategory.restaurant;
    }
    if (normalized.contains('cafe') ||
        normalized.contains('coffee') ||
        normalized.contains('카페') ||
        normalized.contains('커피') ||
        normalized.contains('starbucks') ||
        normalized.contains('스타벅스')) {
      return WorkerSupplyCategory.cafe;
    }
    if (normalized.contains('parking') ||
        normalized.contains('주차') ||
        normalized.contains('park')) {
      return WorkerSupplyCategory.parkingLot;
    }
    if (normalized.contains('ev') ||
        normalized.contains('charger') ||
        normalized.contains('electric') ||
        normalized.contains('전기차') ||
        normalized.contains('충전소') ||
        normalized.contains('충전기')) {
      return WorkerSupplyCategory.evCharger;
    }
    if (normalized.contains('hardware') || normalized.contains('철물')) {
      return WorkerSupplyCategory.hardware;
    }
    return null;
  }

  Map<WorkerSupplyCategory, List<WorkerSupplyPlace>> _groupPlacesByCategory(
    List<WorkerSupplyPlace> rows, {
    required WorkerSupplyCategory? fallbackCategory,
  }) {
    final grouped = <WorkerSupplyCategory, List<WorkerSupplyPlace>>{
      for (final category in WorkerSupplyCategory.values)
        category: <WorkerSupplyPlace>[],
    };
    for (final row in rows) {
      final category = WorkerSupplyCategory.fromServerKey(row.category) ??
          _fallbackCategoryFromName(row.categoryName) ??
          fallbackCategory;
      if (category == null) continue;
      grouped[category]!.add(row);
    }
    return grouped;
  }

  String? _zoomInRequiredMessage(Object error) {
    final unwrapped = unwrapHttpClientException(error);
    if (unwrapped is! HttpStatusException) return null;
    final body = unwrapped.body;
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final errorSection = map['error'];
    if (errorSection is Map) {
      final code = errorSection['code']?.toString().trim().toUpperCase() ?? '';
      if (code == 'ZOOM_IN_REQUIRED') {
        return '지도 영역을 더 넓혀주세요.';
      }
    }
    final topLevelCode = map['code']?.toString().trim().toUpperCase() ?? '';
    if (topLevelCode == 'ZOOM_IN_REQUIRED') {
      return '지도 영역을 더 넓혀주세요.';
    }
    return null;
  }

  void _showTemporaryHint(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _normalizeDialPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return digits;
  }

  Future<void> _copyToClipboard(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
  }

  Future<void> _openPhoneDialerPrefilled(String phoneRaw) async {
    final digits = _normalizeDialPhone(phoneRaw);
    if (digits.isEmpty) return;
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: digits),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) return;
    _showTemporaryHint('전화 앱을 열 수 없습니다.');
  }

  Future<void> _copyPhoneAndOpenDialer(String phoneRaw) async {
    await _copyToClipboard(phoneRaw);
    await _openPhoneDialerPrefilled(phoneRaw);
  }

  String? _cursorContractMessage(Object error) {
    final unwrapped = unwrapHttpClientException(error);
    if (unwrapped is! HttpStatusException) return null;
    final body = unwrapped.body;
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final detail = map['error'];
    String code = '';
    if (detail is Map) {
      code = detail['code']?.toString().trim().toUpperCase() ?? '';
    }
    if (code.isEmpty) {
      code = map['code']?.toString().trim().toUpperCase() ?? '';
    }
    switch (code) {
      case 'CURSOR_SORT_MISMATCH':
      case 'CURSOR_SCOPE_MISMATCH':
      case 'CURSOR_EXPIRED':
      case 'INVALID_CURSOR':
        return '목록 기준이 변경되어 결과를 처음부터 다시 불러옵니다.';
      default:
        return null;
    }
  }

  Future<LatLng> _resolveMyLocationCenter() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('위치 권한이 없어 내 위치 반경 조회를 할 수 없습니다.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _loadFromMyLocation({
    required bool moveMap,
    required bool fetchData,
  }) async {
    try {
      final center = await _resolveMyLocationCenter();
      if (!mounted) return;
      setState(() {
        _mapCenter = center;
        _myLocationCenter = center;
        if (_places.isNotEmpty) {
          _setPlacesByCategory(_placesByCategory);
        }
      });
      if (moveMap) {
        if (_mapController != null && _mapReady) {
          _mapController!.setCenter(center);
        } else {
          _pendingCenterOnMapReady = true;
        }
      }
      if (fetchData) {
        await _searchNearby(center: center);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      if (fetchData) {
        await _searchNearby(center: _mapCenter);
      }
    }
  }

  Future<void> _searchNearby({required LatLng center}) async {
    final requestId = ++_latestSearchRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
      _showSearchInViewButton = false;
    });
    try {
      final source = ref.read(workerSupplyPlacesSourceProvider);
      final selectedCategory = _selectedCategory;
      const searchQuery = '';
      if (selectedCategory == null) {
        if (!mounted || requestId != _latestSearchRequestId) return;
        setState(() {
          _setPlacesByCategory(
            const <WorkerSupplyCategory, List<WorkerSupplyPlace>>{},
          );
          _clusters = const <WorkerSupplyCluster>[];
          _nextCursor = null;
          _nextCursorTtlSeconds = null;
          _lastSearchMapLevel = _currentMapLevel;
          _hasLoadedOnce = true;
          _isLoading = false;
        });
        return;
      }
      final categories = _categoriesForRequest(
        integrated: false,
        selectedCategory: selectedCategory,
      );
      final cacheKey = _buildNearbyCacheKey(
        categoryServerKeys: categories,
        searchQuery: searchQuery,
        center: center,
      );
      final rows = await _requestWithCache(
        cacheKey: cacheKey,
        requestBuilder: () async {
          final page = await source.searchNearby(
            categoryServerKeys: categories,
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: _radiusMeters,
            searchQuery: searchQuery,
            limit: 40,
            sort: _serverSortMode(),
            sortDirection: WorkerSupplyServerSortDirection.asc,
          );
          return (
            rowsByCategory: _groupPlacesByCategory(
              page.items,
              fallbackCategory: selectedCategory,
            ),
            clusters: page.clusters,
            responseKind: page.responseKind,
            errors: const <String>[],
            nextCursor: page.nextCursor,
            nextCursorTtlSeconds: page.nextCursorTtlSeconds,
          );
        },
      );
      if (!mounted || requestId != _latestSearchRequestId) return;
      setState(() {
        _setPlacesByCategory(rows.rowsByCategory);
        final hasItems =
            rows.rowsByCategory.values.any((list) => list.isNotEmpty);
        _clusters = hasItems ? const <WorkerSupplyCluster>[] : rows.clusters;
        _nextCursor = rows.nextCursor;
        _nextCursorTtlSeconds = rows.nextCursorTtlSeconds;
        _lastSearchUsedBounds = false;
        _lastNearbyCenter = center;
        _lastBounds = null;
        _lastCategories = categories;
        _lastSearchQuery = searchQuery;
        _lastSearchMapLevel = _currentMapLevel;
        _error = null;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted || requestId != _latestSearchRequestId) return;
      final cursorMessage = _cursorContractMessage(e);
      final zoomMessage = _zoomInRequiredMessage(e);
      setState(() {
        _error = zoomMessage != null ? null : (cursorMessage ?? e.toString());
        if (cursorMessage != null) {
          _nextCursor = null;
        }
      });
      if (zoomMessage != null) {
        _showTemporaryHint(zoomMessage);
      }
    } finally {
      if (mounted && requestId == _latestSearchRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchInCurrentView() async {
    final bounds = _currentBounds;
    if (bounds == null) return;
    final requestId = ++_latestSearchRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
      _showSearchInViewButton = false;
    });
    try {
      final source = ref.read(workerSupplyPlacesSourceProvider);
      final selectedCategory = _selectedCategory;
      const searchQuery = '';
      if (selectedCategory == null) {
        if (!mounted || requestId != _latestSearchRequestId) return;
        setState(() {
          _setPlacesByCategory(
            const <WorkerSupplyCategory, List<WorkerSupplyPlace>>{},
          );
          _clusters = const <WorkerSupplyCluster>[];
          _nextCursor = null;
          _nextCursorTtlSeconds = null;
          _lastSearchMapLevel = _currentMapLevel;
          _hasLoadedOnce = true;
          _isLoading = false;
        });
        return;
      }
      final categories = _categoriesForRequest(
        integrated: false,
        selectedCategory: selectedCategory,
      );
      final sw = bounds.getSouthWest();
      final ne = bounds.getNorthEast();
      final cacheKey = _buildBoundsCacheKey(
        categoryServerKeys: categories,
        searchQuery: searchQuery,
        sw: sw,
        ne: ne,
        mapLevel: _currentMapLevel,
      );
      final rows = await _requestWithCache(
        cacheKey: cacheKey,
        requestBuilder: () async {
          final page = await source.searchInBounds(
            categoryServerKeys: categories,
            swLatitude: sw.latitude,
            swLongitude: sw.longitude,
            neLatitude: ne.latitude,
            neLongitude: ne.longitude,
            mapLevel: _serverMapLevelForBounds(_currentMapLevel),
            searchQuery: searchQuery,
            limit: 40,
            sort: _serverSortMode(),
            sortDirection: WorkerSupplyServerSortDirection.asc,
            clusterMode: WorkerSupplyClusterMode.forceItems,
          );
          return (
            rowsByCategory: _groupPlacesByCategory(
              page.items,
              fallbackCategory: selectedCategory,
            ),
            clusters: page.clusters,
            responseKind: page.responseKind,
            errors: const <String>[],
            nextCursor: page.nextCursor,
            nextCursorTtlSeconds: page.nextCursorTtlSeconds,
          );
        },
      );
      if (!mounted || requestId != _latestSearchRequestId) return;
      setState(() {
        _setPlacesByCategory(rows.rowsByCategory);
        final hasItems =
            rows.rowsByCategory.values.any((list) => list.isNotEmpty);
        _clusters = hasItems ? const <WorkerSupplyCluster>[] : rows.clusters;
        _nextCursor = rows.nextCursor;
        _nextCursorTtlSeconds = rows.nextCursorTtlSeconds;
        _lastSearchUsedBounds = true;
        _lastNearbyCenter = null;
        _lastBounds = bounds;
        _lastCategories = categories;
        _lastSearchQuery = searchQuery;
        _lastSearchMapLevel = _currentMapLevel;
        _error = null;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted || requestId != _latestSearchRequestId) return;
      final cursorMessage = _cursorContractMessage(e);
      final zoomMessage = _zoomInRequiredMessage(e);
      setState(() {
        _error = zoomMessage != null ? null : (cursorMessage ?? e.toString());
        if (cursorMessage != null) {
          _nextCursor = null;
        }
      });
      if (zoomMessage != null) {
        _showTemporaryHint(zoomMessage);
      }
    } finally {
      if (mounted && requestId == _latestSearchRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreResults() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.trim().isEmpty || _isLoadingMore) return;
    final activeRequestId = _latestSearchRequestId;
    final categories = _lastCategories;
    if (categories.isEmpty) return;
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });
    try {
      final source = ref.read(workerSupplyPlacesSourceProvider);
      late final WorkerSupplyPlacesPage page;
      if (_lastSearchUsedBounds) {
        final bounds = _lastBounds;
        if (bounds == null) return;
        final sw = bounds.getSouthWest();
        final ne = bounds.getNorthEast();
        page = await source.searchInBounds(
          categoryServerKeys: categories,
          swLatitude: sw.latitude,
          swLongitude: sw.longitude,
          neLatitude: ne.latitude,
          neLongitude: ne.longitude,
          mapLevel: _serverMapLevelForBounds(_currentMapLevel),
          searchQuery: _lastSearchQuery,
          limit: 40,
          sort: _serverSortMode(),
          sortDirection: WorkerSupplyServerSortDirection.asc,
          clusterMode: WorkerSupplyClusterMode.forceItems,
          cursor: cursor,
        );
      } else {
        final center = _lastNearbyCenter;
        if (center == null) return;
        page = await source.searchNearby(
          categoryServerKeys: categories,
          latitude: center.latitude,
          longitude: center.longitude,
          radiusMeters: _radiusMeters,
          searchQuery: _lastSearchQuery,
          limit: 40,
          sort: _serverSortMode(),
          sortDirection: WorkerSupplyServerSortDirection.asc,
          cursor: cursor,
        );
      }
      if (!mounted || activeRequestId != _latestSearchRequestId) return;
      setState(() {
        if (page.items.isNotEmpty) {
          _clusters = const <WorkerSupplyCluster>[];
          final grouped = _groupPlacesByCategory(
            page.items,
            fallbackCategory: _selectedCategory,
          );
          _appendPlacesByCategory(grouped);
        } else if (_places.isEmpty) {
          _clusters = page.clusters;
        }
        _nextCursor = page.nextCursor;
        _nextCursorTtlSeconds = page.nextCursorTtlSeconds;
      });
    } catch (e) {
      if (!mounted || activeRequestId != _latestSearchRequestId) return;
      final cursorMessage = _cursorContractMessage(e);
      final zoomMessage = _zoomInRequiredMessage(e);
      setState(() {
        _error = zoomMessage != null ? null : (cursorMessage ?? e.toString());
        if (cursorMessage != null) {
          _nextCursor = null;
        }
      });
      if (zoomMessage != null) {
        _showTemporaryHint(zoomMessage);
      }
    } finally {
      if (mounted && activeRequestId == _latestSearchRequestId) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _clearMapSearchContext() async {
    if (!mounted) return;
    setState(() {
      _selectedCategory = null;
      _showSearchInViewButton = false;
      _error = null;
      _clusters = const <WorkerSupplyCluster>[];
      _nextCursor = null;
      _nextCursorTtlSeconds = null;
      _lastSearchUsedBounds = false;
      _lastNearbyCenter = null;
      _lastBounds = null;
      _lastCategories = const <String>[];
      _lastSearchQuery = '';
      _lastSearchMapLevel = _currentMapLevel;
      _sheetSelectedPlace = null;
      _sheetSelectedCategory = null;
      _listSheetScrollOffset = 0;
      _pendingListScrollRestore = false;
      _listScrollRestoreScheduled = false;
      _setPlacesByCategory(
          const <WorkerSupplyCategory, List<WorkerSupplyPlace>>{});
    });
  }

  Future<void> _onTapSearchInViewButton() async {
    if (_isLoading) return;
    if (!_showSearchInViewButton ||
        !_isSearchInViewEligible(_selectedCategory)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지도를 이동한 뒤 재검색을 눌러주세요.')),
      );
      return;
    }
    await _searchInCurrentView();
  }

  Future<void> _onTapClearFiltersButton() async {
    if (_isLoading) return;
    await _clearMapSearchContext();
  }

  List<Marker> _buildPlaceMarkers() {
    return _markerPlaceById.entries
        .where(
            (entry) => entry.value.latitude != 0 && entry.value.longitude != 0)
        .map(
      (entry) {
        final category =
            _markerCategoryById[entry.key] ?? WorkerSupplyCategory.hardware;
        return Marker(
          markerId: entry.key,
          latLng: LatLng(entry.value.latitude, entry.value.longitude),
          width: 34,
          height: 44,
          markerImageSrc: _categoryMarkerImageSrc(category),
          offsetX: 17,
          offsetY: 43,
          infoWindowContent: '',
          infoWindowRemovable: false,
        );
      },
    ).toList(growable: false);
  }

  List<Marker> _buildFallbackClusterMarkers() {
    return _clusters
        .where((cluster) => cluster.latitude != 0 && cluster.longitude != 0)
        .map(
          (cluster) => Marker(
            markerId: '__cluster__:${cluster.id}',
            latLng: LatLng(cluster.latitude, cluster.longitude),
            width: 36,
            height: 44,
            infoWindowContent: '',
            infoWindowRemovable: false,
          ),
        )
        .toList(growable: false);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final placeMarkers = _buildPlaceMarkers();
    if (placeMarkers.isNotEmpty) {
      markers.addAll(placeMarkers);
    } else if (_clusters.isNotEmpty) {
      markers.addAll(_buildFallbackClusterMarkers());
    }
    final my = _myLocationCenter;
    if (my != null) {
      markers.add(
        Marker(
          markerId: _myLocationMarkerId,
          latLng: my,
          width: 26,
          height: 26,
          markerImageSrc: _myLocationDotMarkerImageSrc,
          offsetX: 13,
          offsetY: 13,
          infoWindowContent: '',
          infoWindowRemovable: false,
        ),
      );
    }
    return markers;
  }

  WorkerSupplyPlace? _placeByMarkerId(String markerId) {
    return _markerPlaceById[markerId];
  }

  void _closeSheetPlaceDetail() {
    if (_sheetSelectedPlace == null && _sheetSelectedCategory == null) return;
    setState(() {
      _sheetSelectedPlace = null;
      _sheetSelectedCategory = null;
      _pendingListScrollRestore = true;
    });
    _scheduleListScrollRestore();
  }

  void _scheduleListScrollRestore() {
    if (_listScrollRestoreScheduled) return;
    _listScrollRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _listScrollRestoreScheduled = false;
      if (!mounted ||
          !_pendingListScrollRestore ||
          _sheetSelectedPlace != null) {
        return;
      }
      final ctrl = _resultsSheetScrollController;
      if (ctrl == null || !ctrl.hasClients) return;
      final target = _listSheetScrollOffset.clamp(
        0.0,
        ctrl.position.maxScrollExtent,
      );
      try {
        await ctrl.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // Ignore transient scroll attachment errors.
      }
      if (!mounted) return;
      _pendingListScrollRestore = false;
    });
  }

  bool _consumeDetailSheetBackIfNeeded() {
    if (_sheetSelectedPlace == null) return false;
    _closeSheetPlaceDetail();
    return true;
  }

  Future<void> _zoomIntoClusterAndSearch(WorkerSupplyCluster cluster) async {
    if (_isLoading || _mapController == null || !_mapReady) return;
    HapticFeedback.selectionClick();
    final target = LatLng(cluster.latitude, cluster.longitude);
    final nextLevel =
        _currentMapLevel > 5 ? 5 : (_currentMapLevel - 2).clamp(1, 14);
    try {
      _mapController!.setCenter(target);
      _mapController!.setLevel(nextLevel);
      setState(() {
        _mapCenter = target;
        _currentMapLevel = nextLevel;
        _sheetSelectedPlace = null;
        _sheetSelectedCategory = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      final bounds = await _mapController!.getBounds();
      if (!mounted) return;
      setState(() {
        _currentBounds = bounds;
      });
      await _searchInCurrentView();
    } catch (_) {
      _showTemporaryHint('지도를 확대한 뒤 다시 검색해 주세요.');
    }
  }

  Future<void> _focusPlaceAndOpenActions(
    WorkerSupplyCategory category,
    WorkerSupplyPlace place,
  ) async {
    final markerId = _markerIdForPlace(category, place);
    final selected = _markerPlaceById[markerId] ?? place;
    final center = LatLng(place.latitude, place.longitude);
    setState(() {
      _mapCenter = center;
    });
    if (_mapController != null && _mapReady) {
      await _mapController!.setCenter(center);
    } else {
      _pendingCenterOnMapReady = true;
    }
    if (!mounted) return;
    final listOffset = (_resultsSheetScrollController != null &&
            _resultsSheetScrollController!.hasClients)
        ? _resultsSheetScrollController!.offset
        : 0.0;
    setState(() {
      _listSheetScrollOffset = listOffset < 0 ? 0 : listOffset;
      _sheetSelectedPlace = selected;
      _sheetSelectedCategory = category;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = _resultsSheetScrollController;
      if (!mounted || ctrl == null || !ctrl.hasClients) return;
      if (ctrl.offset > 0) ctrl.jumpTo(0);
    });
  }

  Future<void> _syncMapDragLockFromSheets() async {
    final shouldLock = _sheetPointerCount > 0;
    if (_mapDragLockedBySheet == shouldLock) return;
    _mapDragLockedBySheet = shouldLock;
    if (_mapController == null || !_mapReady) return;
    try {
      await _mapController!.setDraggable(!shouldLock);
    } catch (_) {
      // Ignore lock toggle errors to avoid blocking UI gestures.
    }
  }

  Future<void> _onBottomSheetPointerDown() async {
    _sheetPointerCount += 1;
    await _syncMapDragLockFromSheets();
  }

  Future<void> _onBottomSheetPointerUpOrCancel() async {
    _sheetPointerCount = (_sheetPointerCount - 1).clamp(0, 99);
    await _syncMapDragLockFromSheets();
  }

  Future<void> _onCategoryChipsPointerDown() async {
    _sheetPointerCount += 1;
    await _syncMapDragLockFromSheets();
  }

  Future<void> _onCategoryChipsPointerUpOrCancel() async {
    _sheetPointerCount = (_sheetPointerCount - 1).clamp(0, 99);
    await _syncMapDragLockFromSheets();
  }

  Widget _buildKakaoCategoryChip(
    BuildContext context, {
    required WorkerSupplyCategory category,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accent = _categoryAccentColor(context, category);
    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.98)
          : cs.surface.withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 2.0 : 1.0,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(10),
            vertical: context.rsi(7),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.75)
                  : cs.outlineVariant.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: context.rsi(16),
                color: selected ? cs.primary : accent,
              ),
              SizedBox(width: context.rsi(6)),
              Text(
                category.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? cs.primary : cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(8),
          vertical: context.rsi(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.rsi(13), color: cs.onSurfaceVariant),
            SizedBox(width: context.rsi(4)),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? tint,
  }) {
    final cs = Theme.of(context).colorScheme;
    final base = tint ?? cs.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: base.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(7),
          vertical: context.rsi(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.rsi(12), color: base),
            SizedBox(width: context.rsi(4)),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: base,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceResultCard(
    BuildContext context, {
    required WorkerSupplyCategory category,
    required WorkerSupplyPlace place,
    required WorkerSupplyFuelPriceDisplayMode fuelDisplayMode,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isGas = category == WorkerSupplyCategory.gasStation;
    final isRestaurant = category == WorkerSupplyCategory.restaurant;
    final accent = _categoryAccentColor(context, category);
    final name = place.name.trim().isEmpty ? '(이름 없음)' : place.name.trim();
    final address = place.displayAddress.trim().isEmpty
        ? '주소 정보 없음'
        : place.displayAddress.trim();

    return Material(
      color: Colors.white,
      elevation: 0.4,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          _focusPlaceAndOpenActions(category, place);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(10),
            vertical: context.rsi(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: context.rsi(34),
                height: context.rsi(34),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child:
                    Icon(category.icon, size: context.rsi(18), color: accent),
              ),
              SizedBox(width: context.rsi(9)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    SizedBox(height: context.rsi(2)),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    SizedBox(height: context.rsi(6)),
                    Wrap(
                      spacing: context.rsi(6),
                      runSpacing: context.rsi(4),
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(7),
                              vertical: context.rsi(3),
                            ),
                            child: Text(
                              _formatDistance(place),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        if (place.openNow != null)
                          _buildMetaPill(
                            context,
                            icon: place.openNow!
                                ? Icons.access_time_filled_rounded
                                : Icons.access_time_rounded,
                            label: place.openNow! ? '영업중' : '영업종료',
                            tint: place.openNow!
                                ? const Color(0xFF2E7D32)
                                : cs.onSurfaceVariant,
                          ),
                        if (place.rating != null)
                          _buildMetaPill(
                            context,
                            icon: Icons.star_rounded,
                            label:
                                '${place.rating!.toStringAsFixed(1)}${(place.reviewCount != null && place.reviewCount! > 0) ? ' (${NumberFormat.decimalPattern('ko_KR').format(place.reviewCount)})' : ''}',
                            tint: const Color(0xFFFB8C00),
                          ),
                        if (isRestaurant &&
                            (place.restaurantCuisine?.trim().isNotEmpty ??
                                false))
                          _buildMetaPill(
                            context,
                            icon: Icons.restaurant_menu_rounded,
                            label: place.restaurantCuisine!.trim(),
                            tint: cs.primary,
                          ),
                        if (isGas)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rsi(7),
                                vertical: context.rsi(3),
                              ),
                              child: _buildFuelSummaryForList(
                                context,
                                place,
                                fuelDisplayMode,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rsi(6)),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: context.rsi(20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryResultSection(
    BuildContext context,
    _WorkerSupplyCategorySection section,
    WorkerSupplyFuelPriceDisplayMode fuelDisplayMode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final accent = _categoryAccentColor(context, section.category);
    final rows = section.places;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.rsi(11)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: context.rsi(28),
                  height: context.rsi(28),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    section.category.icon,
                    size: context.rsi(16),
                    color: accent,
                  ),
                ),
                SizedBox(width: context.rsi(8)),
                Expanded(
                  child: Text(
                    section.category.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rsi(6)),
            if (rows.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: context.rsi(6)),
                child: Text(
                  '결과 없음',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              )
            else
              ...List.generate(rows.length, (index) {
                final place = rows[index];
                return Padding(
                  padding: EdgeInsets.only(
                    top: context.rsi(index == 0 ? 0 : 8),
                  ),
                  child: _buildPlaceResultCard(
                    context,
                    category: section.category,
                    place: place,
                    fuelDisplayMode: fuelDisplayMode,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlaceDetailSheetChildren(
    BuildContext context,
    WorkerSupplyPlace place,
    WorkerSupplyCategory? category,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final query = '${place.name} ${place.displayAddress}'.trim();
    final isGasStation = _isGasCategory(category: category, place: place);
    final distanceLabel = _formatDistance(place);
    final categoryLabel = category?.label ?? place.categoryName.trim();

    return <Widget>[
      Row(
        children: [
          IconButton(
            onPressed: _closeSheetPlaceDetail,
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.onSurface,
              backgroundColor:
                  cs.surfaceContainerHighest.withValues(alpha: 0.7),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          SizedBox(width: context.rsi(6)),
          Expanded(
            child: Text(
              '업체 정보',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      SizedBox(height: context.rsi(10)),
      Text(
        place.name.trim().isEmpty ? '(이름 없음)' : place.name.trim(),
        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      SizedBox(height: context.rsi(6)),
      Text(
        place.displayAddress.trim().isEmpty
            ? '(주소 없음)'
            : place.displayAddress.trim(),
        style: tt.bodyLarge,
      ),
      SizedBox(height: context.rsi(4)),
      Text(
        '내 위치 기준 $distanceLabel',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      if (categoryLabel.isNotEmpty) ...[
        SizedBox(height: context.rsi(4)),
        Text(
          categoryLabel,
          style: tt.labelLarge?.copyWith(color: cs.primary),
        ),
      ],
      if (place.phone.trim().isNotEmpty) ...[
        SizedBox(height: context.rsi(4)),
        Text(
          place.phone.trim(),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
      if (isGasStation) ...[
        SizedBox(height: context.rsi(12)),
        Container(
          padding: EdgeInsets.all(context.rsi(10)),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Wrap(
            spacing: context.rsi(8),
            runSpacing: context.rsi(8),
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(10),
                  vertical: context.rsi(7),
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  '휘발유 ${_formatFuelPrice(place.gasolinePrice)}',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(10),
                  vertical: context.rsi(7),
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  '경유 ${_formatFuelPrice(place.dieselPrice)}',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      SizedBox(height: context.rsi(14)),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await _copyToClipboard(place.displayAddress);
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('주소 복사'),
            ),
          ),
          SizedBox(width: context.rsi(8)),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: place.phone.trim().isEmpty
                  ? null
                  : () async {
                      await _copyPhoneAndOpenDialer(place.phone);
                    },
              icon: const Icon(Icons.phone_outlined),
              label: const Text('복사 후 전화앱'),
            ),
          ),
        ],
      ),
      SizedBox(height: context.rsi(10)),
      MapRouteActionButtons(
        onKakao: () async {
          final destination = place.name.trim().isEmpty
              ? place.displayAddress.trim()
              : place.name.trim();
          await MapNavigationLauncher.openKakaoNaviRoute(
            destinationName: destination,
            latitude: place.latitude,
            longitude: place.longitude,
          );
        },
        onTmap: () async {
          await MapNavigationLauncher.openTmapSearch(query);
        },
      ),
      SizedBox(height: context.rsi(8)),
    ];
  }

  Widget _buildResultsBottomSheet(
    BuildContext context,
    WorkerSupplyCategory? selectedCategory,
    WorkerSupplyFuelPriceDisplayMode fuelDisplayMode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final detailPlace = _sheetSelectedPlace;
    final detailCategory = _sheetSelectedCategory;
    final showingDetail = detailPlace != null;
    final section = selectedCategory == null
        ? null
        : _WorkerSupplyCategorySection(
            category: selectedCategory,
            places: _placesByCategory[selectedCategory] ?? const [],
          );
    final hasAnyItems = (section?.places.isNotEmpty ?? false);
    final hasAny = hasAnyItems;
    final resultCount = section?.places.length ?? 0;
    final title = selectedCategory == null
        ? '카테고리를 선택하면 주변 업체를 조회합니다'
        : _lastSearchUsedBounds
            ? '이 화면의 ${selectedCategory.label} (${resultCount}건)'
            : '내 주변 ${selectedCategory.label} (${resultCount}건)';
    final subtitle = selectedCategory == null
        ? '카테고리를 선택해 가까운 순으로 업체를 확인할 수 있어요'
        : '가까운 순으로 정렬되어 있어요';
    final hasMoreResults =
        _nextCursor != null && _nextCursor!.trim().isNotEmpty;
    final hasContext = _hasSearchContext(selectedCategory);
    final sheetProfile =
        '${hasAny ? 'result' : 'empty'}-item-${hasContext ? 'ctx' : 'idle'}';
    final bool compactState = !hasAny && !hasContext;
    final double minSheetSize = compactState ? 0.15 : 0.18;
    final double initialSheetSize = hasAny ? 0.38 : (hasContext ? 0.28 : 0.18);
    const double maxSheetSize = 0.86;
    final List<double> snapSizes = hasAny
        ? const <double>[0.24, 0.38, 0.62, 0.86]
        : (hasContext
            ? const <double>[0.18, 0.28, 0.5]
            : const <double>[0.15, 0.22, 0.36]);

    return Positioned.fill(
      child: DraggableScrollableSheet(
        key: ValueKey<String>(sheetProfile),
        initialChildSize: initialSheetSize,
        minChildSize: minSheetSize,
        maxChildSize: maxSheetSize,
        snap: true,
        snapSizes: snapSizes,
        builder: (context, scrollController) {
          _resultsSheetScrollController = scrollController;
          if (!showingDetail && _pendingListScrollRestore) {
            _scheduleListScrollRestore();
          }
          return SafeArea(
            top: false,
            bottom: false,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                _onBottomSheetPointerDown();
              },
              onPointerUp: (_) {
                _onBottomSheetPointerUpOrCancel();
              },
              onPointerCancel: (_) {
                _onBottomSheetPointerUpOrCancel();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                onDoubleTap: () {},
                child: Container(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(14),
                      context.rsi(10),
                      context.rsi(14),
                      context.rsi(12),
                    ),
                    child: ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Center(
                          child: Container(
                            width: context.rsi(34),
                            height: context.rsi(4),
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        SizedBox(height: context.rsi(10)),
                        if (showingDetail) ...[
                          ..._buildPlaceDetailSheetChildren(
                            context,
                            detailPlace,
                            detailCategory,
                          ),
                        ] else ...[
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          SizedBox(height: context.rsi(4)),
                          Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          SizedBox(height: context.rsi(8)),
                          if (hasMoreResults)
                            Wrap(
                              spacing: context.rsi(6),
                              runSpacing: context.rsi(6),
                              children: [
                                _buildInfoBadge(
                                  context,
                                  icon: Icons.expand_circle_down_outlined,
                                  label: '추가 결과 있음',
                                ),
                              ],
                            ),
                          if (hasMoreResults) SizedBox(height: context.rsi(10)),
                          if (hasAny) ...[
                            if (section != null)
                              _buildCategoryResultSection(
                                context,
                                section,
                                fuelDisplayMode,
                              ),
                            if (_nextCursor != null &&
                                _nextCursor!.trim().isNotEmpty) ...[
                              SizedBox(height: context.rsi(10)),
                              Align(
                                alignment: Alignment.center,
                                child: FilledButton.tonalIcon(
                                  onPressed:
                                      _isLoadingMore ? null : _loadMoreResults,
                                  icon: _isLoadingMore
                                      ? SizedBox(
                                          width: context.rsi(14),
                                          height: context.rsi(14),
                                          child:
                                              const CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    _isLoadingMore
                                        ? '불러오는 중...'
                                        : _nextCursorTtlSeconds == null
                                            ? '목록 더보기'
                                            : '목록 더보기 (${_nextCursorTtlSeconds}s)',
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            SizedBox(height: context.rsi(26)),
                            Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLowest
                                      .withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.rsi(14),
                                    vertical: context.rsi(14),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      SizedBox(height: context.rsi(6)),
                                      Text(
                                        selectedCategory == null
                                            ? '카테고리를 선택해 주세요.'
                                            : '주변 데이터가 없습니다.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: context.rsi(8)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final category = _selectedCategory;
    final fuelDisplayMode = ref.watch(workerSupplyFuelPriceDisplayModeProvider);
    final canShowSearchInViewButton =
        _showSearchInViewButton && _isSearchInViewEligible(category);

    return BackButtonListener(
      onBackButtonPressed: () async => _consumeDetailSheetBackIfNeeded(),
      child: PopScope(
        canPop: _sheetSelectedPlace == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _consumeDetailSheetBackIfNeeded();
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: KakaoMap(
                  center: _mapCenter,
                  currentLevel: 5,
                  minLevel: 1,
                  maxLevel: 14,
                  markers: _mapReady ? _buildMarkers() : const <Marker>[],
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    try {
                      if (_pendingCenterOnMapReady) {
                        await controller.setCenter(_mapCenter);
                        _pendingCenterOnMapReady = false;
                      }
                      final bounds = await controller.getBounds();
                      if (!mounted) return;
                      setState(() {
                        _mapReady = true;
                        _currentBounds = bounds;
                      });
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        _mapReady = false;
                        _error = '지도를 초기화하지 못했습니다. 카카오 키 설정을 확인해주세요.\n$e';
                      });
                    }
                  },
                  onMarkerTap: (markerId, _, __) {
                    if (markerId == _myLocationMarkerId) return;
                    if (markerId.startsWith('__cluster__:')) {
                      final clusterId =
                          markerId.replaceFirst('__cluster__:', '');
                      final target =
                          _clusters.where((row) => row.id == clusterId);
                      if (target.isNotEmpty) {
                        _zoomIntoClusterAndSearch(target.first);
                      }
                      return;
                    }
                    final place = _placeByMarkerId(markerId);
                    if (place == null) return;
                    final category = _markerCategoryById[markerId];
                    _focusPlaceAndOpenActions(
                      category ?? WorkerSupplyCategory.hardware,
                      place,
                    );
                  },
                  onCameraIdle: (latLng, level) async {
                    if (!_mapReady) return;
                    _mapCenter = latLng;
                    _currentMapLevel = level;
                    if (_mapController == null) return;
                    try {
                      final bounds = await _mapController!.getBounds();
                      if (!mounted) return;
                      setState(() {
                        _currentBounds = bounds;
                        _showSearchInViewButton =
                            _isSearchInViewEligible(_selectedCategory) &&
                                _hasMapMovedEnoughFromLastSearch();
                      });
                    } catch (_) {}
                  },
                ),
              ),
              if (_isLoading)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Color(0x24000000),
                      child: Center(
                        child: HammerLoadingIndicator(
                          size: 104,
                          label: '주변 데이터를 조회 중...',
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + context.rsi(10),
                left: context.rsi(12),
                right: context.rsi(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) {
                        _onCategoryChipsPointerDown();
                      },
                      onPointerUp: (_) {
                        _onCategoryChipsPointerUpOrCancel();
                      },
                      onPointerCancel: (_) {
                        _onCategoryChipsPointerUpOrCancel();
                      },
                      child: SizedBox(
                        height: context.rsi(42),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: WorkerSupplyCategory.values.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: context.rsi(6)),
                          itemBuilder: (context, index) {
                            final c = WorkerSupplyCategory.values[index];
                            return _buildKakaoCategoryChip(
                              context,
                              category: c,
                              selected: category == c,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedCategory = c;
                                  _sheetSelectedPlace = null;
                                  _sheetSelectedCategory = null;
                                });
                                _searchNearby(center: _mapCenter);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    if (category != null) ...[
                      SizedBox(height: context.rsi(8)),
                      Padding(
                        padding: EdgeInsets.only(top: context.rsi(2)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (canShowSearchInViewButton)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.rsi(14),
                                    vertical: context.rsi(10),
                                  ),
                                ),
                                onPressed: _onTapSearchInViewButton,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('이 화면에서 검색'),
                              ),
                            SizedBox(width: context.rsi(6)),
                            IconButton(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: cs.onSurface,
                                backgroundColor:
                                    cs.surface.withValues(alpha: 0.96),
                                side: BorderSide(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.7),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rsi(10),
                                  vertical: context.rsi(10),
                                ),
                              ),
                              onPressed: _onTapClearFiltersButton,
                              icon: const Icon(Icons.restart_alt_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null && _error!.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: context.rsi(8)),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(context.rsi(10)),
                            child: Text(
                              _error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onErrorContainer,
                                  ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildResultsBottomSheet(context, category, fuelDisplayMode),
              Positioned(
                right: context.rsi(12),
                bottom: context.rsi(120) + MediaQuery.paddingOf(context).bottom,
                child: FloatingActionButton.small(
                  heroTag: 'worker-supply-my-location',
                  onPressed: _isLoading
                      ? null
                      : () {
                          _loadFromMyLocation(moveMap: true, fetchData: false);
                        },
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
