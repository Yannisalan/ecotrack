import 'api_service.dart';

extension ActivityApi on ApiService {
  /// category -> {unit: 'km', types: [...]}
  Future<Map<String, Map<String, dynamic>>> getActivityOptions() async {
    final data = await request('GET', '/api/activities/options', auth: false);
    final cats = data['categories'] as Map<String, dynamic>;
    return cats.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  }

  Future<Map<String, dynamic>> createActivity({
    required String category,
    required String type,
    required double quantity,
    required String date,
    bool resend = false,
  }) async {
    final data = await request(
      'POST',
      '/api/activities',
      body: {
        'category': category,
        'type': type,
        'quantity': quantity,
        'date': date,
        if (resend) 'resend': true,
      },
    );
    return data['activity'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateActivity(
    int id, {
    required String category,
    required String type,
    required double quantity,
    required String date,
  }) async {
    final data = await request(
      'PATCH',
      '/api/activities/$id',
      body: {
        'category': category,
        'type': type,
        'quantity': quantity,
        'date': date,
      },
    );
    return data['activity'] as Map<String, dynamic>;
  }

  Future<void> deleteActivity(int id) async {
    await request('DELETE', '/api/activities/$id');
  }

  /// Returns {activities: [...], total, limit, offset}
  Future<Map<String, dynamic>> listActivities({
    String? category,
    int limit = 20,
    int offset = 0,
  }) {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }
    return request(
      'GET',
      '/api/activities',
      query: query,
    );
  }
}
