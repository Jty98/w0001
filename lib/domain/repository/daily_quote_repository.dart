import 'package:w0001/data/model/daily_quote_models.dart';

abstract class DailyQuoteRepository {
  Future<TodayDailyQuote> getToday();

  Future<DailyQuotePage> list({
    int page = 1,
    int pageSize = 30,
    String query = '',
    bool? isActive,
  });

  Future<DailyQuote> save(DailyQuote quote);

  Future<void> delete(int id);

  Future<DailyQuoteSettings> getSettings();

  Future<DailyQuoteSettings> updateSettings(DailyQuoteSettings settings);

  Future<TodayDailyQuote> overrideToday({
    required String author,
    required String authorProfile,
    required String message,
  });

  Future<TodayDailyQuote> clearTodayOverride();
}
