import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/daily_quote_models.dart';
import 'package:w0001/util/api_endpoint.dart';

final class DailyQuotesRemoteApi {
  DailyQuotesRemoteApi(this._http);

  final AppHttpClient _http;

  Future<TodayDailyQuote> getToday() async {
    final response = await _http.get<dynamic>(ApiEndpoint.dailyQuotesToday);
    return TodayDailyQuote.fromJson(saParseObject(response.data));
  }

  Future<DailyQuotePage> list({
    int page = 1,
    int pageSize = 30,
    String query = '',
    bool? isActive,
  }) async {
    final response = await _http.get<dynamic>(
      ApiEndpoint.dailyQuotes,
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (isActive != null) 'is_active': isActive,
      },
    );
    return _parsePage(response.data, requestedPage: page, pageSize: pageSize);
  }

  Future<DailyQuote> create(DailyQuote quote) async {
    final response = await _http.post<dynamic>(
      ApiEndpoint.dailyQuotes,
      data: quote.toWriteJson(),
    );
    return DailyQuote.fromJson(saParseObject(response.data));
  }

  Future<DailyQuote> update(DailyQuote quote) async {
    final response = await _http.patch<dynamic>(
      ApiEndpoint.dailyQuotesId(quote.id),
      data: quote.toWriteJson(),
    );
    return DailyQuote.fromJson(saParseObject(response.data));
  }

  Future<void> delete(int id) async {
    await _http.delete<dynamic>(ApiEndpoint.dailyQuotesId(id));
  }

  Future<DailyQuoteSettings> getSettings() async {
    final response = await _http.get<dynamic>(ApiEndpoint.dailyQuotesSettings);
    return DailyQuoteSettings.fromJson(saParseObject(response.data));
  }

  Future<DailyQuoteSettings> updateSettings(
    DailyQuoteSettings settings,
  ) async {
    final response = await _http.put<dynamic>(
      ApiEndpoint.dailyQuotesSettings,
      data: settings.toJson(),
    );
    return DailyQuoteSettings.fromJson(saParseObject(response.data));
  }

  Future<TodayDailyQuote> overrideToday({
    required String author,
    required String authorProfile,
    required String message,
  }) async {
    final response = await _http.put<dynamic>(
      ApiEndpoint.dailyQuotesTodayOverride,
      data: <String, dynamic>{
        'author': author.trim(),
        'author_profile': authorProfile.trim(),
        'message': message.trim(),
      },
    );
    return TodayDailyQuote.fromJson(saParseObject(response.data));
  }

  Future<TodayDailyQuote> clearTodayOverride() async {
    final response = await _http.delete<dynamic>(
      ApiEndpoint.dailyQuotesTodayOverride,
    );
    return TodayDailyQuote.fromJson(saParseObject(response.data));
  }

  static DailyQuotePage _parsePage(
    Object? data, {
    required int requestedPage,
    required int pageSize,
  }) {
    if (data is! Map) {
      final items = saMapList(data, DailyQuote.fromJson);
      return DailyQuotePage(
        items: items,
        page: requestedPage,
        pageSize: pageSize,
        total: items.length,
      );
    }
    final root = Map<String, dynamic>.from(data);
    final nested = root['data'];
    final body = nested is Map ? Map<String, dynamic>.from(nested) : root;
    final items = saMapList(body, DailyQuote.fromJson);
    int number(Object? value, int fallback) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return DailyQuotePage(
      items: items,
      page: number(body['page'], requestedPage),
      pageSize: number(body['page_size'] ?? body['pageSize'], pageSize),
      total: number(
        body['total'] ?? body['total_count'] ?? body['totalCount'],
        items.length,
      ),
    );
  }
}
