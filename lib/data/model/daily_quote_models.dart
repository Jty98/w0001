enum DailyQuoteRotationMode {
  random,
  sequential;

  String toJson() => name;

  static DailyQuoteRotationMode fromJson(Object? value) {
    return value?.toString().toLowerCase() == 'sequential'
        ? DailyQuoteRotationMode.sequential
        : DailyQuoteRotationMode.random;
  }
}

enum DailyQuoteSource {
  pool,
  override;

  static DailyQuoteSource fromJson(Object? value) {
    return value?.toString().toLowerCase() == 'override'
        ? DailyQuoteSource.override
        : DailyQuoteSource.pool;
  }
}

class DailyQuote {
  const DailyQuote({
    required this.id,
    required this.author,
    required this.authorProfile,
    required this.message,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String author;
  final String authorProfile;
  final String message;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      id: _jsonInt(json['id']),
      author: _jsonString(json['author']),
      authorProfile:
          _jsonString(json['author_profile'] ?? json['authorProfile']),
      message: _jsonString(json['message']),
      isActive:
          _jsonBool(json['is_active'] ?? json['isActive'], fallback: true),
      createdAt: _jsonDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _jsonDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toWriteJson() => <String, dynamic>{
        'author': author.trim(),
        'author_profile': authorProfile.trim(),
        'message': message.trim(),
        'is_active': isActive,
      };

  DailyQuote copyWith({
    int? id,
    String? author,
    String? authorProfile,
    String? message,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyQuote(
      id: id ?? this.id,
      author: author ?? this.author,
      authorProfile: authorProfile ?? this.authorProfile,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DailyQuotePage {
  const DailyQuotePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<DailyQuote> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasNext => page * pageSize < total;
}

class TodayDailyQuote {
  const TodayDailyQuote({
    required this.date,
    required this.quote,
    required this.source,
    this.nextRefreshAt,
  });

  final String date;
  final DailyQuote quote;
  final DailyQuoteSource source;
  final DateTime? nextRefreshAt;

  bool get isOverride => source == DailyQuoteSource.override;

  factory TodayDailyQuote.fromJson(Map<String, dynamic> json) {
    final rawQuote = json['quote'];
    final quoteJson = rawQuote is Map
        ? Map<String, dynamic>.from(rawQuote)
        : Map<String, dynamic>.from(json);
    return TodayDailyQuote(
      date: _jsonString(json['date']),
      quote: DailyQuote.fromJson(quoteJson),
      source: DailyQuoteSource.fromJson(json['source']),
      nextRefreshAt:
          _jsonDate(json['next_refresh_at'] ?? json['nextRefreshAt']),
    );
  }
}

class DailyQuoteSettings {
  const DailyQuoteSettings({
    this.mode = DailyQuoteRotationMode.random,
    this.recentHistoryLimit = 30,
    this.timezone = 'Asia/Seoul',
  });

  final DailyQuoteRotationMode mode;
  final int recentHistoryLimit;
  final String timezone;

  factory DailyQuoteSettings.fromJson(Map<String, dynamic> json) {
    return DailyQuoteSettings(
      mode: DailyQuoteRotationMode.fromJson(json['mode']),
      recentHistoryLimit: _jsonInt(
        json['recent_history_limit'] ?? json['recentHistoryLimit'],
        fallback: 30,
      ),
      timezone: _jsonString(json['timezone'], fallback: 'Asia/Seoul'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.toJson(),
        'recent_history_limit': recentHistoryLimit,
        'timezone': timezone,
      };

  DailyQuoteSettings copyWith({
    DailyQuoteRotationMode? mode,
    int? recentHistoryLimit,
    String? timezone,
  }) {
    return DailyQuoteSettings(
      mode: mode ?? this.mode,
      recentHistoryLimit: recentHistoryLimit ?? this.recentHistoryLimit,
      timezone: timezone ?? this.timezone,
    );
  }
}

int _jsonInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _jsonString(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  return text == null ? fallback : text;
}

bool _jsonBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return fallback;
}

DateTime? _jsonDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
