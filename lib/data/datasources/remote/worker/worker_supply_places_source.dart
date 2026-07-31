import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/kakao_local_map_api.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/worker_supply_place.dart';
import 'package:w0001/util/api_endpoint.dart';

enum WorkerSupplyServerSort { distance, name, fuelPrice }

enum WorkerSupplyServerSortDirection { asc, desc }

enum WorkerSupplyClusterMode { auto, forceClusters, forceItems }

enum WorkerSupplyResponseKind { items, clusters }

class WorkerSupplyPlacesPage {
  const WorkerSupplyPlacesPage({
    required this.items,
    this.clusters = const <WorkerSupplyCluster>[],
    this.responseKind = WorkerSupplyResponseKind.items,
    this.nextCursor,
    this.sortedBy,
    this.sortDirection,
    this.approxTotal,
    this.pageSize,
    this.nextCursorTtlSeconds,
    this.cachePolicy,
    this.etagScope,
    this.cacheHit,
    this.eTag,
    this.notModified = false,
  });

  final List<WorkerSupplyPlace> items;
  final List<WorkerSupplyCluster> clusters;
  final WorkerSupplyResponseKind responseKind;
  final String? nextCursor;
  final String? sortedBy;
  final String? sortDirection;
  final int? approxTotal;
  final int? pageSize;
  final int? nextCursorTtlSeconds;
  final String? cachePolicy;
  final String? etagScope;
  final bool? cacheHit;
  final String? eTag;
  final bool notModified;
}

abstract interface class WorkerSupplyPlacesSource {
  Future<WorkerSupplyPlacesPage> searchNearby({
    required List<String> categoryServerKeys,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String searchQuery,
    int limit,
    WorkerSupplyServerSort sort,
    WorkerSupplyServerSortDirection sortDirection,
    String? cursor,
  });

  Future<WorkerSupplyPlacesPage> searchInBounds({
    required List<String> categoryServerKeys,
    required double swLatitude,
    required double swLongitude,
    required double neLatitude,
    required double neLongitude,
    int? mapLevel,
    String searchQuery,
    int limit,
    WorkerSupplyServerSort sort,
    WorkerSupplyServerSortDirection sortDirection,
    WorkerSupplyClusterMode clusterMode,
    String? cursor,
  });
}

final class WorkerSupplyPlacesKakaoSource implements WorkerSupplyPlacesSource {
  WorkerSupplyPlacesKakaoSource(this._kakaoApi);

  final KakaoLocalMapApi _kakaoApi;

  String _keywordForCategory(String categoryServerKey) {
    switch (categoryServerKey.trim().toLowerCase()) {
      case 'gas_station':
        return '주유소';
      case 'restaurant':
        return '음식점';
      case 'convenience_store':
        return '편의점';
      case 'cafe':
        return '카페';
      case 'parking_lot':
        return '주차장';
      case 'ev_charger':
        return '전기차 충전소';
      case 'hardware':
      default:
        return '철물점';
    }
  }

  WorkerSupplyPlace _withFallbackCategory(
    WorkerSupplyPlace place,
    String categoryServerKey,
  ) {
    final normalized = categoryServerKey.trim().toLowerCase();
    if (place.category.trim().isNotEmpty) return place;
    return WorkerSupplyPlace(
      id: place.id,
      name: place.name,
      category: normalized,
      categoryName: place.categoryName,
      address: place.address,
      roadAddress: place.roadAddress,
      latitude: place.latitude,
      longitude: place.longitude,
      phone: place.phone,
      placeUrl: place.placeUrl,
      distanceMeters: place.distanceMeters,
      gasolinePrice: place.gasolinePrice,
      dieselPrice: place.dieselPrice,
      priceUpdatedAt: place.priceUpdatedAt,
      priceSource: place.priceSource,
      priceConfidence: place.priceConfidence,
      priceStale: place.priceStale,
    );
  }

  Future<WorkerSupplyPlacesPage> _searchByCategories({
    required List<String> categoryServerKeys,
    required Future<List<WorkerSupplyPlace>> Function(
      String categoryServerKey,
      String keyword,
    ) request,
  }) async {
    final normalizedCategories = categoryServerKeys
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedCategories.isEmpty) {
      return const WorkerSupplyPlacesPage(items: <WorkerSupplyPlace>[]);
    }
    final merged = <WorkerSupplyPlace>[];
    final seen = <String>{};
    for (final category in normalizedCategories) {
      final rows = await request(category, _keywordForCategory(category));
      for (final row in rows) {
        final normalized = _withFallbackCategory(row, category);
        final dedupeKey =
            '${normalized.category}:${normalized.id}:${normalized.latitude}:${normalized.longitude}';
        if (!seen.add(dedupeKey)) continue;
        merged.add(normalized);
      }
    }
    return WorkerSupplyPlacesPage(items: merged);
  }

  @override
  Future<WorkerSupplyPlacesPage> searchNearby({
    required List<String> categoryServerKeys,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String searchQuery = '',
    int limit = 40,
    WorkerSupplyServerSort sort = WorkerSupplyServerSort.distance,
    WorkerSupplyServerSortDirection sortDirection =
        WorkerSupplyServerSortDirection.asc,
    String? cursor,
  }) {
    return _searchByCategories(
      categoryServerKeys: categoryServerKeys,
      request: (categoryServerKey, keyword) => _kakaoApi.searchNearbyByKeyword(
        keyword: keyword,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        searchQuery: searchQuery,
      ),
    );
  }

  @override
  Future<WorkerSupplyPlacesPage> searchInBounds({
    required List<String> categoryServerKeys,
    required double swLatitude,
    required double swLongitude,
    required double neLatitude,
    required double neLongitude,
    int? mapLevel,
    String searchQuery = '',
    int limit = 40,
    WorkerSupplyServerSort sort = WorkerSupplyServerSort.distance,
    WorkerSupplyServerSortDirection sortDirection =
        WorkerSupplyServerSortDirection.asc,
    WorkerSupplyClusterMode clusterMode = WorkerSupplyClusterMode.auto,
    String? cursor,
  }) {
    return _searchByCategories(
      categoryServerKeys: categoryServerKeys,
      request: (categoryServerKey, keyword) => _kakaoApi.searchInBoundsByKeyword(
        keyword: keyword,
        swLatitude: swLatitude,
        swLongitude: swLongitude,
        neLatitude: neLatitude,
        neLongitude: neLongitude,
        searchQuery: searchQuery,
      ),
    );
  }
}

final class WorkerSupplyPlacesServerSource implements WorkerSupplyPlacesSource {
  WorkerSupplyPlacesServerSource(this._http);

  final AppHttpClient _http;
  final Map<String, WorkerSupplyPlacesPage> _etagResponseCache =
      <String, WorkerSupplyPlacesPage>{};
  final Map<String, String> _etagByRequestKey = <String, String>{};

  String _requestCacheKey(
    String mode, {
    required List<String> categoryServerKeys,
    required String searchQuery,
    required Map<String, dynamic> query,
  }) {
    final categories = categoryServerKeys
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false)
      ..sort();
    final pairs = query.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final serializedQuery =
        pairs.map((e) => '${e.key}=${e.value}').join('&');
    return [
      mode,
      categories.join(','),
      searchQuery.trim().toLowerCase(),
      serializedQuery,
    ].join('|');
  }

  WorkerSupplyPlacesPage _parseSearchPage(
    dynamic data, {
    required String? responseEtag,
    required String? responseCachePolicy,
    required String? responseEtagScope,
  }) {
    final root = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    final paged = saParsePagedList<WorkerSupplyPlace>(root, WorkerSupplyPlace.fromJson);
    final rawClusters = root['clusters'];
    final clusters = <WorkerSupplyCluster>[];
    if (rawClusters is List) {
      for (final row in rawClusters) {
        if (row is Map) {
          clusters.add(WorkerSupplyCluster.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    final metaRaw = root['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : const <String, dynamic>{};
    final responseKindRaw =
        (meta['response_kind'] ?? root['response_kind'] ?? 'items')
            .toString()
            .trim()
            .toLowerCase();
    final responseKind = responseKindRaw == 'clusters'
        ? WorkerSupplyResponseKind.clusters
        : WorkerSupplyResponseKind.items;

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }
    bool? asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final raw = v.trim().toLowerCase();
        if (raw == 'true' || raw == '1') return true;
        if (raw == 'false' || raw == '0') return false;
      }
      return null;
    }
    String? metaEtag;
    if (meta.isNotEmpty) {
      metaEtag = meta['etag']?.toString();
    }
    return WorkerSupplyPlacesPage(
      items: paged.items,
      clusters: clusters,
      responseKind: responseKind,
      nextCursor: paged.nextCursor,
      sortedBy: meta['sorted_by']?.toString(),
      sortDirection: meta['sort_direction']?.toString(),
      approxTotal: asInt(meta['approx_total'] ?? root['total']),
      pageSize: asInt(meta['page_size']),
      nextCursorTtlSeconds: asInt(meta['next_cursor_ttl']),
      cachePolicy: meta['cache_policy']?.toString() ?? responseCachePolicy,
      etagScope: meta['etag_scope']?.toString() ?? responseEtagScope,
      cacheHit: asBool(meta['cache_hit']),
      eTag: responseEtag ?? metaEtag,
    );
  }

  Future<WorkerSupplyPlacesPage> _search({
    required String mode,
    required List<String> categoryServerKeys,
    required Map<String, dynamic> query,
    required String searchQuery,
  }) async {
    final requestKey = _requestCacheKey(
      mode,
      categoryServerKeys: categoryServerKeys,
      searchQuery: searchQuery,
      query: query,
    );
    final ifNoneMatch = _etagByRequestKey[requestKey];
    final response = await _http.raw.get<dynamic>(
      ApiEndpoint.workerSupplyPlacesSearch,
      queryParameters: query,
      options: Options(
        headers: <String, String>{
          if (ifNoneMatch != null && ifNoneMatch.trim().isNotEmpty)
            'If-None-Match': ifNoneMatch,
        },
        validateStatus: (status) =>
            status != null && ((status >= 200 && status < 300) || status == 304),
      ),
    );
    if (response.statusCode == 304) {
      final cached = _etagResponseCache[requestKey];
      if (cached != null) {
        return WorkerSupplyPlacesPage(
          items: cached.items,
          nextCursor: cached.nextCursor,
          eTag: cached.eTag,
          notModified: true,
        );
      }
    }
    final page = _parseSearchPage(
      response.data,
      responseEtag: response.headers.value('etag'),
      responseCachePolicy: response.headers.value('x-cache-policy'),
      responseEtagScope: response.headers.value('x-etag-scope'),
    );
    if (page.eTag != null && page.eTag!.trim().isNotEmpty) {
      _etagByRequestKey[requestKey] = page.eTag!;
      _etagResponseCache[requestKey] = page;
    }
    return page;
  }

  @override
  Future<WorkerSupplyPlacesPage> searchNearby({
    required List<String> categoryServerKeys,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String searchQuery = '',
    int limit = 40,
    WorkerSupplyServerSort sort = WorkerSupplyServerSort.distance,
    WorkerSupplyServerSortDirection sortDirection =
        WorkerSupplyServerSortDirection.asc,
    String? cursor,
  }) async {
    final sortKey = switch (sort) {
      WorkerSupplyServerSort.distance => 'distance',
      WorkerSupplyServerSort.name => 'name',
      WorkerSupplyServerSort.fuelPrice => 'fuel_price',
    };
    final sortDirKey = switch (sortDirection) {
      WorkerSupplyServerSortDirection.asc => 'asc',
      WorkerSupplyServerSortDirection.desc => 'desc',
    };
    final query = <String, dynamic>{
      'mode': 'nearby',
      'categories': categoryServerKeys.join(','),
      'lat': latitude,
      'lng': longitude,
      'radius': radiusMeters,
      'limit': limit,
      'sort': sortKey,
      'sort_direction': sortDirKey,
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (searchQuery.trim().isNotEmpty) 'q': searchQuery.trim(),
    };
    return _search(
      mode: 'nearby',
      categoryServerKeys: categoryServerKeys,
      query: query,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<WorkerSupplyPlacesPage> searchInBounds({
    required List<String> categoryServerKeys,
    required double swLatitude,
    required double swLongitude,
    required double neLatitude,
    required double neLongitude,
    int? mapLevel,
    String searchQuery = '',
    int limit = 40,
    WorkerSupplyServerSort sort = WorkerSupplyServerSort.distance,
    WorkerSupplyServerSortDirection sortDirection =
        WorkerSupplyServerSortDirection.asc,
    WorkerSupplyClusterMode clusterMode = WorkerSupplyClusterMode.auto,
    String? cursor,
  }) async {
    final sortKey = switch (sort) {
      WorkerSupplyServerSort.distance => 'distance',
      WorkerSupplyServerSort.name => 'name',
      WorkerSupplyServerSort.fuelPrice => 'fuel_price',
    };
    final sortDirKey = switch (sortDirection) {
      WorkerSupplyServerSortDirection.asc => 'asc',
      WorkerSupplyServerSortDirection.desc => 'desc',
    };
    final clusterKey = switch (clusterMode) {
      WorkerSupplyClusterMode.auto => 'auto',
      WorkerSupplyClusterMode.forceClusters => 'true',
      WorkerSupplyClusterMode.forceItems => 'false',
    };
    final query = <String, dynamic>{
      'mode': 'in_bounds',
      'categories': categoryServerKeys.join(','),
      'sw_lat': swLatitude,
      'sw_lng': swLongitude,
      'ne_lat': neLatitude,
      'ne_lng': neLongitude,
      'limit': limit,
      'sort': sortKey,
      'sort_direction': sortDirKey,
      'cluster': clusterKey,
      if (mapLevel != null) 'map_level': mapLevel,
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (searchQuery.trim().isNotEmpty) 'q': searchQuery.trim(),
    };
    return _search(
      mode: 'in_bounds',
      categoryServerKeys: categoryServerKeys,
      query: query,
      searchQuery: searchQuery,
    );
  }
}
