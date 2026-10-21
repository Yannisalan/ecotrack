import 'api_service.dart';

extension NotificationsApi on ApiService {
  Future<Map<String, dynamic>> getNotifications() =>
      request('GET', '/api/notifications');

  Future<Map<String, dynamic>> markNotificationRead(int id) =>
      request('POST', '/api/notifications/$id/read');

  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      request('POST', '/api/notifications/read-all');

  Future<Map<String, dynamic>> deleteNotification(int id) =>
      request('DELETE', '/api/notifications/$id');

  Future<Map<String, dynamic>> getNotificationPreferences() =>
      request('GET', '/api/notifications/preferences');

  Future<Map<String, dynamic>> updateNotificationPreferences(
    Map<String, dynamic> preferences,
  ) =>
      request('PUT', '/api/notifications/preferences', body: preferences);
}
