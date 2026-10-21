import 'package:flutter/foundation.dart';
import '../services/challenges_api.dart';
import '../services/api_service.dart';

class ChallengesProvider extends ChangeNotifier {
  final ApiService api;
  ChallengesProvider(this.api);

  List<Map<String, dynamic>> challenges = [];
  List<Map<String, dynamic>> history = [];
  int points = 0;
  int completedTotal = 0;
  bool loading = false;
  String? error;

  int get completedCount =>
      challenges.where((c) => c['completed'] == true).length;

  List<Map<String, dynamic>> byPeriod(String period) =>
      challenges.where((c) => c['period'] == period).toList();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.getChallenges();
      challenges = (data['challenges'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      history = (data['history'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      points = (data['points'] as num?)?.toInt() ?? 0;
      completedTotal = (data['completed_total'] as num?)?.toInt() ?? 0;
    } on ApiException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }
}
