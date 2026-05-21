import '../services/notification_service.dart';

class NotificationRepository {
  NotificationRepository({required NotificationService notificationService})
      : _notificationService = notificationService;

  final NotificationService _notificationService;

  Future<void> registerDevice() =>
      _notificationService.syncTokenForCurrentUser();

  Future<void> unregisterDevice(String uid) =>
      _notificationService.removeTokenForUser(uid);

  void setChatNavigationHandler(void Function(String? chatId) handler) {
    _notificationService.onNavigateToChat = handler;
  }
}
