import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/activity_api.dart';
import '../services/api_service.dart';

/// A local queue for activities logged while offline. Backed by
/// SharedPreferences so it survives app restarts and needs no native plugin.
class OfflineQueue {
  static const _key = 'offline_activity_queue';

  /// A transport failure (offline/timeout) carries no HTTP status code, so it
  /// is detected structurally rather than by matching the wording of the
  /// message. This keeps the queue behaviour correct regardless of how the
  /// friendly text is phrased.
  static bool isNetworkError(ApiException e) {
    if (e.statusCode != null) return false;
    return e.isNetworkError;
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<void> add(Map<String, dynamic> item) async {
    final items = await load();
    items.add(item);
    await _save(items);
  }

  static Future<void> clear() => _save(const []);

  /// Try to send every queued item. Returns how many were synced. Items that
  /// still fail because the server is unreachable stay queued.
  static Future<int> flush(ApiService api) async {
    final items = await load();
    if (items.isEmpty) return 0;
    final remaining = <Map<String, dynamic>>[];
    int synced = 0;
    for (final item in items) {
      try {
        await api.createActivity(
          category: item['category'] as String,
          type: item['type'] as String,
          quantity: (item['quantity'] as num).toDouble(),
          date: item['date'] as String,
          resend: true, // may already be applied if a prior flush's response was lost
        );
        synced++;
      } on ApiException catch (e) {
        if (isNetworkError(e)) {
          remaining.add(item);
        } else {
          // Permanent failure (validation). Drop it so it does not block sync.
          synced++;
        }
      }
    }
    await _save(remaining);
    return synced;
  }
}

/// Create an activity, falling back to the offline queue on network failure.
/// Returns the created activity, or null when it was queued offline.
Future<Map<String, dynamic>?> createActivityOrQueue(
  ApiService api, {
  required String category,
  required String type,
  required double quantity,
  required String date,
}) async {
  try {
    return await api.createActivity(
      category: category,
      type: type,
      quantity: quantity,
      date: date,
    );
  } on ApiException catch (e) {
    if (OfflineQueue.isNetworkError(e)) {
      await OfflineQueue.add({
        'category': category,
        'type': type,
        'quantity': quantity,
        'date': date,
      });
      return null;
    }
    rethrow;
  }
}
