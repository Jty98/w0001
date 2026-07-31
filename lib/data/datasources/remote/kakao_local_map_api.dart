import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:w0001/data/model/worker_supply_place.dart';

class KakaoLocalMapApi {
  KakaoLocalMapApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://dapi.kakao.com',
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );

  final Dio _dio;

  String _restApiKey() {
    final key = dotenv.env['kakao_rest_api_key']?.trim() ?? '';
    if (key.isEmpty) {
      throw StateError(
        'kakao_rest_api_key가 .env에 없습니다. 카카오 REST API 키를 추가해주세요.',
      );
    }
    return key;
  }

  String _buildQuery({
    required String keyword,
    String searchQuery = '',
  }) {
    final extra = searchQuery.trim();
    if (extra.isEmpty) return keyword.trim();
    return '${keyword.trim()} $extra';
  }

  Future<WorkerSupplyPlace?> _searchBestAddressMatch(String address) async {
    final q = address.trim();
    if (q.isEmpty) return null;
    final key = _restApiKey();
    final r = await _dio.get<Map<String, dynamic>>(
      '/v2/local/search/address.json',
      queryParameters: <String, dynamic>{
        'query': q,
        'page': 1,
        'size': 1,
      },
      options: Options(
        headers: <String, String>{'Authorization': 'KakaoAK $key'},
      ),
    );
    final data = r.data ?? const <String, dynamic>{};
    final docs = data['documents'];
    if (docs is! List || docs.isEmpty) return null;
    final first = docs.first;
    if (first is! Map) return null;
    final m = Map<String, dynamic>.from(first);
    final xRaw = m['x']?.toString();
    final yRaw = m['y']?.toString();
    final x = double.tryParse(xRaw ?? '');
    final y = double.tryParse(yRaw ?? '');
    if (x == null || y == null || x == 0 || y == 0) return null;
    return WorkerSupplyPlace(
      id: 'address_${xRaw ?? x}_${yRaw ?? y}',
      name: m['address_name']?.toString().trim().isNotEmpty == true
          ? m['address_name'].toString()
          : q,
      category: '',
      categoryName: '주소',
      address: m['address_name']?.toString() ??
          m['road_address_name']?.toString() ??
          q,
      roadAddress: m['road_address_name']?.toString() ??
          m['address_name']?.toString() ??
          q,
      phone: '',
      placeUrl: '',
      latitude: y,
      longitude: x,
      openNow: null,
      distanceMeters: null,
      rating: null,
      reviewCount: null,
      gasolinePrice: null,
      dieselPrice: null,
      restaurantCuisine: null,
    );
  }

  /// 좌표가 없는 텍스트(현장명/주소)에서 카카오 로컬 키워드 검색으로 대표 1건을 찾는다.
  Future<WorkerSupplyPlace?> searchBestMatch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final key = _restApiKey();
    final r = await _dio.get<Map<String, dynamic>>(
      '/v2/local/search/keyword.json',
      queryParameters: <String, dynamic>{
        'query': q,
        'page': 1,
        'size': 1,
        'sort': 'accuracy',
      },
      options: Options(
        headers: <String, String>{'Authorization': 'KakaoAK $key'},
      ),
    );
    final data = r.data ?? const <String, dynamic>{};
    final docs = data['documents'];
    if (docs is! List || docs.isEmpty) return null;
    final first = docs.first;
    if (first is! Map) return null;
    final mapped = WorkerSupplyPlace.fromJson(Map<String, dynamic>.from(first));
    if (mapped.latitude == 0 || mapped.longitude == 0) return null;
    return mapped;
  }

  /// 주소를 우선 해석하고, 실패하면 키워드 검색으로 좌표를 찾는다.
  Future<WorkerSupplyPlace?> resolveBestMatch({
    required String address,
    String keyword = '',
  }) async {
    final byAddress = await _searchBestAddressMatch(address);
    if (byAddress != null) return byAddress;
    final q = '$keyword ${address.trim()}'.trim();
    return searchBestMatch(q);
  }

  Future<List<WorkerSupplyPlace>> searchNearbyByKeyword({
    required String keyword,
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
    String searchQuery = '',
    int maxPages = 3,
    int pageSize = 10,
  }) async {
    final key = _restApiKey();
    final query = _buildQuery(keyword: keyword, searchQuery: searchQuery);
    final radius = radiusMeters.clamp(100, 20000);
    final out = <WorkerSupplyPlace>[];
    final seen = <String>{};

    for (var page = 1; page <= maxPages.clamp(1, 45); page++) {
      final r = await _dio.get<Map<String, dynamic>>(
        '/v2/local/search/keyword.json',
        queryParameters: <String, dynamic>{
          'query': query,
          'x': longitude,
          'y': latitude,
          'radius': radius,
          'page': page,
          'size': pageSize.clamp(1, 15),
          'sort': 'distance',
        },
        options: Options(
          headers: <String, String>{'Authorization': 'KakaoAK $key'},
        ),
      );
      final data = r.data ?? const <String, dynamic>{};
      final docs = data['documents'];
      if (docs is! List) continue;
      for (final row in docs) {
        if (row is! Map) continue;
        final place =
            WorkerSupplyPlace.fromJson(Map<String, dynamic>.from(row));
        if (!seen.add(place.id)) continue;
        out.add(place);
      }
    }
    return out;
  }

  Future<List<WorkerSupplyPlace>> searchInBoundsByKeyword({
    required String keyword,
    required double swLatitude,
    required double swLongitude,
    required double neLatitude,
    required double neLongitude,
    String searchQuery = '',
    int maxPages = 3,
    int pageSize = 10,
  }) async {
    final key = _restApiKey();
    final query = _buildQuery(keyword: keyword, searchQuery: searchQuery);
    final rect = '$swLongitude,$swLatitude,$neLongitude,$neLatitude';
    final out = <WorkerSupplyPlace>[];
    final seen = <String>{};
    for (var page = 1; page <= maxPages.clamp(1, 45); page++) {
      final r = await _dio.get<Map<String, dynamic>>(
        '/v2/local/search/keyword.json',
        queryParameters: <String, dynamic>{
          'query': query,
          'rect': rect,
          'page': page,
          'size': pageSize.clamp(1, 15),
          'sort': 'accuracy',
        },
        options: Options(
          headers: <String, String>{'Authorization': 'KakaoAK $key'},
        ),
      );
      final data = r.data ?? const <String, dynamic>{};
      final docs = data['documents'];
      if (docs is! List) continue;
      for (final row in docs) {
        if (row is! Map) continue;
        final place =
            WorkerSupplyPlace.fromJson(Map<String, dynamic>.from(row));
        if (!seen.add(place.id)) continue;
        out.add(place);
      }
    }
    return out;
  }
}
