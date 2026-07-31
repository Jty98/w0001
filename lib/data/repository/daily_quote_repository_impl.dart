import 'package:w0001/data/datasources/remote/daily_quotes_api.dart';
import 'package:w0001/data/model/daily_quote_models.dart';
import 'package:w0001/domain/repository/daily_quote_repository.dart';

final class DailyQuoteRepositoryImpl implements DailyQuoteRepository {
  DailyQuoteRepositoryImpl(this._api);

  final DailyQuotesRemoteApi _api;

  @override
  Future<TodayDailyQuote> getToday() => _api.getToday();

  @override
  Future<DailyQuotePage> list({
    int page = 1,
    int pageSize = 30,
    String query = '',
    bool? isActive,
  }) {
    return _api.list(
      page: page,
      pageSize: pageSize,
      query: query,
      isActive: isActive,
    );
  }

  @override
  Future<DailyQuote> save(DailyQuote quote) {
    _validate(quote);
    return quote.id > 0 ? _api.update(quote) : _api.create(quote);
  }

  @override
  Future<void> delete(int id) {
    if (id <= 0) return Future<void>.value();
    return _api.delete(id);
  }

  @override
  Future<DailyQuoteSettings> getSettings() => _api.getSettings();

  @override
  Future<DailyQuoteSettings> updateSettings(
    DailyQuoteSettings settings,
  ) {
    if (settings.recentHistoryLimit < 1 || settings.recentHistoryLimit > 365) {
      throw ArgumentError('중복 방지 기간은 1일에서 365일 사이여야 합니다.');
    }
    return _api.updateSettings(settings);
  }

  @override
  Future<TodayDailyQuote> overrideToday({
    required String author,
    required String authorProfile,
    required String message,
  }) {
    _validateText(
      author: author,
      authorProfile: authorProfile,
      message: message,
    );
    return _api.overrideToday(
      author: author,
      authorProfile: authorProfile,
      message: message,
    );
  }

  @override
  Future<TodayDailyQuote> clearTodayOverride() => _api.clearTodayOverride();

  static void _validate(DailyQuote quote) {
    _validateText(
      author: quote.author,
      authorProfile: quote.authorProfile,
      message: quote.message,
    );
  }

  static void _validateText({
    required String author,
    required String authorProfile,
    required String message,
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError('명언 내용을 입력해 주세요.');
    }
    if (author.trim().isEmpty) {
      throw ArgumentError('저자를 입력해 주세요.');
    }
    if (message.trim().length > 500) {
      throw ArgumentError('명언은 500자 이하로 입력해 주세요.');
    }
    if (author.trim().length > 100 || authorProfile.trim().length > 100) {
      throw ArgumentError('저자와 소개는 각각 100자 이하로 입력해 주세요.');
    }
  }
}
