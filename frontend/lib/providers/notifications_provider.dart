import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/notifications_api.dart';

class NotificationsProvider extends ChangeNotifier {
  final ApiService api;
  NotificationsProvider(this.api);

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> items = [];
  int unread = 0;

  Map<String, dynamic>? preferences;
  bool preferencesLoading = false;
  String? preferencesError;

  int _requestId = 0;

  Future<void> load() async {
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.getNotifications();
      if (id != _requestId) return;
      items = (data['notifications'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      unread = (data['unread'] as num?)?.toInt() ?? _countUnread();
    } on ApiException catch (e) {
      if (id != _requestId) return;
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  int _countUnread() => items.where((n) => n['read'] != true).length;

  Future<void> markRead(int id) async {
    final index = items.indexWhere((n) => n['id'] == id);
    if (index < 0 || items[index]['read'] == true) return;
    items[index] = {...items[index], 'read': true};
    unread = unread > 0 ? unread - 1 : 0;
    notifyListeners();
    try {
      final data = await api.markNotificationRead(id);
      unread = (data['unread'] as num?)?.toInt() ?? unread;
      notifyListeners();
    } on ApiException {
      await load();
    }
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    items = items.map((n) => {...n, 'read': true}).toList();
    unread = 0;
    notifyListeners();
    try {
      await api.markAllNotificationsRead();
    } on ApiException {
      await load();
    }
  }

  Future<void> dismiss(int id) async {
    final existing = items.where((n) => n['id'] == id).toList();
    if (existing.isEmpty) return;
    items = items.where((n) => n['id'] != id).toList();
    if (existing.first['read'] != true && unread > 0) unread -= 1;
    notifyListeners();
    try {
      final data = await api.deleteNotification(id);
      unread = (data['unread'] as num?)?.toInt() ?? unread;
      notifyListeners();
    } on ApiException {
      await load();
    }
  }

  Future<void> loadPreferences() async {
    preferencesLoading = true;
    preferencesError = null;
    notifyListeners();
    try {
      final data = await api.getNotificationPreferences();
      preferences =
          Map<String, dynamic>.from(data['preferences'] as Map? ?? const {});
    } on ApiException catch (e) {
      preferencesError = e.message;
    }
    preferencesLoading = false;
    notifyListeners();
  }

  Future<bool> updatePreference(String key, Object value) async {
    final before = preferences == null
        ? null
        : Map<String, dynamic>.from(preferences!);
    preferences = {...?preferences, key: value};
    preferencesError = null;
    notifyListeners();
    try {
      final data = await api.updateNotificationPreferences({key: value});
      preferences =
          Map<String, dynamic>.from(data['preferences'] as Map? ?? const {});
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      preferences = before;
      preferencesError = e.message;
      notifyListeners();
      return false;
    }
  }
}
