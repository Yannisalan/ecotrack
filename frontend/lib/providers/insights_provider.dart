import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/insights_api.dart';

class InsightsProvider extends ChangeNotifier {
  final ApiService api;
  InsightsProvider(this.api);

  String period = 'week';
  Map<String, dynamic>? data;
  bool loading = false;
  String? error;

  int _requestId = 0;

  Future<void> load({String? period}) async {
    if (period != null) this.period = period;
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.getInsights(period: this.period);
      if (id != _requestId) return;
      data = result;
    } on ApiException catch (e) {
      if (id != _requestId) return;
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setPeriod(String value) async {
    if (value == period) return;
    await load(period: value);
  }
}
