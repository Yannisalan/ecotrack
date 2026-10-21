import 'api_service.dart';

extension InsightsApi on ApiService {
  Future<Map<String, dynamic>> getInsights({String period = 'week'}) =>
      request('GET', '/api/insights', query: {'period': period});
}
