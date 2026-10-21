import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/stats_api.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService api;
  DashboardProvider(this.api);

  String period = 'week'; // 'week' = last 7 days, 'month' = last 30 days
  bool loading = false;
  String? error;
  Map<String, dynamic>? summary;
  Map<String, dynamic>? score; // null when there is no data in the period
  Map<String, dynamic>? scoreExplanation;
  Map<String, dynamic>? comparison; // current vs previous equal-length window
  List<Map<String, dynamic>> recommendations = [];

  int _requestId = 0;

  Future<void> load() async {
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        api.getSummary(period),
        api.getScore(period),
        api.getRecommendations(period),
        api.getCompare(period),
      ]);
      if (id != _requestId) return; // a newer request replaced this one
      summary = results[0] as Map<String, dynamic>;
      final scoreData = results[1] as Map<String, dynamic>;
      score = scoreData['eco_score'] as Map<String, dynamic>?;
      scoreExplanation = scoreData['explanation'] as Map<String, dynamic>?;
      recommendations = results[2] as List<Map<String, dynamic>>;
      comparison = results[3] as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (id != _requestId) return;
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setPeriod(String value) async {
    if (value == period) return;
    period = value;
    await load();
  }
}
