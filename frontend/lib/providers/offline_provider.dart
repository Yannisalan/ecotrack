import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/offline.dart';

/// Exposes how many activities are waiting to sync and lets the user flush
/// the offline queue. The queue itself is managed by [OfflineQueue].
class OfflineProvider extends ChangeNotifier {
  final ApiService api;
  OfflineProvider(this.api);

  int pending = 0;
  bool syncing = false;

  Future<void> refreshCount() async {
    pending = (await OfflineQueue.load()).length;
    notifyListeners();
  }

  /// Send every queued item. Returns how many synced. Callers should reload
  /// the dashboard afterwards (new data is now on the server).
  Future<int> sync() async {
    if (syncing) return 0;
    syncing = true;
    notifyListeners();
    int synced = 0;
    try {
      synced = await OfflineQueue.flush(api);
    } finally {
      syncing = false;
      await refreshCount();
    }
    return synced;
  }
}
