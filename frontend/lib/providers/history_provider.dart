import 'package:flutter/foundation.dart';
import '../services/activity_api.dart';
import '../services/api_service.dart';

class HistoryProvider extends ChangeNotifier {
  final ApiService api;
  HistoryProvider(this.api);

  static const pageSize = 20;

  String? category; // null = all categories
  List<Map<String, dynamic>> items = [];
  int total = 0;
  bool loading = false;
  bool loadingMore = false;
  String? error;

  int _requestId = 0;

  bool get hasMore => items.length < total;

  Future<void> load() async {
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.listActivities(
        category: category,
        limit: pageSize,
        offset: 0,
      );
      if (id != _requestId) return;
      items = (data['activities'] as List).cast<Map<String, dynamic>>();
      total = (data['total'] as num).toInt();
    } on ApiException catch (e) {
      if (id != _requestId) return;
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final id = _requestId;
    loadingMore = true;
    notifyListeners();
    List<Map<String, dynamic>>? more;
    try {
      final data = await api.listActivities(
        category: category,
        limit: pageSize,
        offset: items.length,
      );
      more = (data['activities'] as List).cast<Map<String, dynamic>>();
      total = (data['total'] as num).toInt();
    } on ApiException catch (e) {
      if (id == _requestId) error = e.message;
    }
    if (id == _requestId && more != null) items = [...items, ...more];
    loadingMore = false;
    notifyListeners();
  }

  Future<void> setCategory(String? value) async {
    if (value == category) return;
    category = value;
    await load();
  }

  /// Returns null on success, or an error message.
  Future<String?> delete(int id) async {
    try {
      await api.deleteActivity(id);
      items = items.where((a) => a['id'] != id).toList();
      if (total > 0) total -= 1;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
