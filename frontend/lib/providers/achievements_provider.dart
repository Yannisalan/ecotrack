import 'package:flutter/foundation.dart';
import '../services/achievements_api.dart';
import '../services/api_service.dart';

class AchievementsProvider extends ChangeNotifier {
  final ApiService api;
  AchievementsProvider(this.api);

  List<Map<String, dynamic>> achievements = [];
  int currentStreak = 0;
  int longestStreak = 0;
  bool loading = false;
  String? error;

  int get unlocked => achievements.where((a) => a['earned'] == true).length;
  int get total => achievements.length;

  List<Map<String, dynamic>> byCategory(String category) =>
      achievements.where((a) => a['category'] == category).toList();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.getAchievements();
      achievements = (data['achievements'] as List)
          .cast<Map<String, dynamic>>();
      final streak = data['streak'] as Map<String, dynamic>?;
      currentStreak = (streak?['current'] as num?)?.toInt() ?? 0;
      longestStreak = (streak?['longest'] as num?)?.toInt() ?? 0;
    } on ApiException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }
}
