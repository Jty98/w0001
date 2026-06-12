import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/domain/repository/user_notifications_repository.dart';

final class UserNotificationsUseCase {
  UserNotificationsUseCase(this._repository);

  final UserNotificationsRepository _repository;

  Future<List<UserNotificationItem>> list() => _repository.list();

  Future<int> unreadCount() => _repository.unreadCount();

  Future<void> markRead(UserNotificationItem item) => _repository.markRead(
        item.id,
        isLocalOnly: item.isLocalOnly,
      );

  Future<void> deleteOne(UserNotificationItem item) => _repository.deleteOne(
        item.id,
        isLocalOnly: item.isLocalOnly,
      );

  Future<void> deleteAll() => _repository.deleteAll();

  Future<void> recordFromFcm({
    required String type,
    required Map<String, dynamic> payload,
    String? title,
    String? body,
  }) =>
      _repository.recordFromFcm(
        type: type,
        payload: payload,
        title: title,
        body: body,
      );
}
