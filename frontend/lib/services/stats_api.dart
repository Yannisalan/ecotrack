import 'api_service.dart';

extension StatsApi on ApiService {
  Future<Map<String, dynamic>> getSummary(String period) =>
      request('GET', '/api/stats/summary', query: {'period': period});

  Future<Map<String, dynamic>> getScore(String period) =>
      request('GET', '/api/stats/score', query: {'period': period});

  Future<Map<String, dynamic>> getCompare(String period) =>
      request('GET', '/api/stats/compare', query: {'period': period});

  Future<Map<String, dynamic>> getStreak() =>
      request('GET', '/api/stats/streak');

  Future<Map<String, dynamic>> getCalendar(String month) async {
    return request('GET', '/api/stats/calendar', query: {'month': month});
  }

  Future<List<Map<String, dynamic>>> getRecommendations(String period) async {
    final data = await request(
      'GET',
      '/api/stats/recommendations',
      query: {'period': period},
    );
    return (data['recommendations'] as List).cast<Map<String, dynamic>>();
  }
}
