import 'api_service.dart';

extension GoalsApi on ApiService {
  Future<List<Map<String, dynamic>>> listGoals() async {
    final data = await requestList('GET', '/api/goals');
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createGoal({
    required String title,
    required String metric,
    required double targetValue,
    String? unit,
    String? endDate,
  }) async {
    return request(
      'POST',
      '/api/goals',
      body: {
        'title': title,
        'metric': metric,
        'target_value': targetValue,
        'unit': ?unit,
        'end_date': ?endDate,
      },
    );
  }

  Future<Map<String, dynamic>> updateGoal(int id, Map<String, dynamic> patch) =>
      request('PATCH', '/api/goals/$id', body: patch);

  Future<void> deleteGoal(int id) async {
    await request('DELETE', '/api/goals/$id');
  }
}
