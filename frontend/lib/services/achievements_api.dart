import 'api_service.dart';

extension AchievementsApi on ApiService {
  /// Achievements + streak for the authenticated user.
  Future<Map<String, dynamic>> getAchievements() =>
      request('GET', '/api/achievements');
}
