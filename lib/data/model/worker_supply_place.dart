class WorkerSupplyPlace {
  const WorkerSupplyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.address,
    required this.roadAddress,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.placeUrl,
    this.distanceMeters,
    this.gasolinePrice,
    this.dieselPrice,
    this.priceUpdatedAt,
    this.priceSource = 'none',
    this.priceConfidence,
    this.priceStale = false,
    this.openNow,
    this.businessHoursSummary,
    this.rating,
    this.reviewCount,
    this.restaurantCuisine,
  });

  final String id;
  final String name;
  final String category;
  final String categoryName;
  final String address;
  final String roadAddress;
  final double latitude;
  final double longitude;
  final String phone;
  final String placeUrl;
  final double? distanceMeters;
  final int? gasolinePrice;
  final int? dieselPrice;
  final DateTime? priceUpdatedAt;
  final String priceSource;
  final String? priceConfidence;
  final bool priceStale;
  final bool? openNow;
  final String? businessHoursSummary;
  final double? rating;
  final int? reviewCount;
  final String? restaurantCuisine;

  factory WorkerSupplyPlace.fromJson(Map<String, dynamic> m) {
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    double? asDouble(dynamic v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) {
        final normalized = v.trim().toLowerCase().replaceAll(',', '');
        if (normalized.isEmpty) return null;
        if (normalized.endsWith('km')) {
          final kmRaw = normalized.substring(0, normalized.length - 2).trim();
          final kmValue = double.tryParse(kmRaw);
          if (kmValue != null) return kmValue * 1000;
        }
        if (normalized.endsWith('m')) {
          final mRaw = normalized.substring(0, normalized.length - 1).trim();
          final mValue = double.tryParse(mRaw);
          if (mValue != null) return mValue;
        }
        return double.tryParse(normalized);
      }
      return null;
    }

    bool asBool(dynamic v, {bool fallback = false}) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true' || t == '1') return true;
        if (t == 'false' || t == '0') return false;
      }
      return fallback;
    }

    DateTime? asDateTime(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is int) {
        final isMs = v > 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(isMs ? v : v * 1000);
      }
      if (v is num) {
        final raw = v.toInt();
        final isMs = raw > 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(isMs ? raw : raw * 1000);
      }
      final raw = v.toString().trim();
      if (raw.isEmpty) return null;
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        final isMs = asInt > 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(isMs ? asInt : asInt * 1000);
      }
      return DateTime.tryParse(raw);
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final raw = m[key];
        if (raw == null) continue;
        final s = raw.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final id = pick(['id', 'sid', 'poi_id']);
    final lat = asDouble(m['lat'] ?? m['latitude'] ?? m['y']) ?? 0;
    final lng = asDouble(m['lng'] ?? m['longitude'] ?? m['x']) ?? 0;
    final numericId = asInt(m['id'] ?? m['sid'] ?? m['poi_id']);

    return WorkerSupplyPlace(
      id: id.isNotEmpty ? id : '${numericId ?? 0}_${lat}_$lng',
      name: pick(['name', 'place_name', 'title']),
      category: pick(['category', 'type']),
      categoryName: pick(['category_name', 'category', 'type']),
      address: pick(['address', 'address_name', 'jibun_address']),
      roadAddress: pick(['road_address', 'road_address_name']),
      latitude: lat,
      longitude: lng,
      phone: pick(['phone', 'telephone', 'tel']),
      placeUrl: pick(['place_url', 'url']),
      distanceMeters: asDouble(m['distance_m'] ?? m['distance']),
      gasolinePrice: asInt(m['gasoline_price']),
      dieselPrice: asInt(m['diesel_price']),
      priceUpdatedAt: asDateTime(m['price_updated_at']),
      priceSource: pick(['price_source', 'priceSource', 'source']).isEmpty
          ? 'none'
          : pick(['price_source', 'priceSource', 'source']),
      priceConfidence: pick(['price_confidence', 'confidence']).isEmpty
          ? null
          : pick(['price_confidence', 'confidence']),
      priceStale: asBool(m['price_stale']),
      openNow: m['open_now'] == null ? null : asBool(m['open_now']),
      businessHoursSummary: pick(
        ['business_hours_summary', 'opening_hours', 'hours_summary'],
      ).isEmpty
          ? null
          : pick(['business_hours_summary', 'opening_hours', 'hours_summary']),
      rating: asDouble(m['rating']),
      reviewCount: asInt(m['review_count'] ?? m['reviews_count']),
      restaurantCuisine: pick(
        ['restaurant_cuisine', 'cuisine', 'food_type'],
      ).isEmpty
          ? null
          : pick(['restaurant_cuisine', 'cuisine', 'food_type']),
    );
  }

  String get displayAddress =>
      roadAddress.trim().isNotEmpty ? roadAddress.trim() : address.trim();
}

class WorkerSupplyCluster {
  const WorkerSupplyCluster({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.byCategory,
    this.minGasolinePrice,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int count;
  final Map<String, int> byCategory;
  final int? minGasolinePrice;

  factory WorkerSupplyCluster.fromJson(Map<String, dynamic> m) {
    double asDouble(dynamic v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0;
      return 0;
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    final rawByCategory = m['by_category'];
    final byCategory = <String, int>{};
    if (rawByCategory is Map) {
      for (final entry in rawByCategory.entries) {
        byCategory[entry.key.toString()] = asInt(entry.value);
      }
    }
    final id = (m['id'] ?? '').toString().trim();
    final lat = asDouble(m['lat'] ?? m['latitude'] ?? m['y']);
    final lng = asDouble(m['lng'] ?? m['longitude'] ?? m['x']);
    return WorkerSupplyCluster(
      id: id.isNotEmpty ? id : 'cluster_${lat}_$lng',
      latitude: lat,
      longitude: lng,
      count: asInt(m['count']),
      byCategory: byCategory,
      minGasolinePrice: m['min_gasoline_price'] == null
          ? null
          : asInt(m['min_gasoline_price']),
    );
  }
}
