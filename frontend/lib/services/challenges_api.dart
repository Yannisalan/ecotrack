import 'api_service.dart';

extension ChallengesApi on ApiService {
  Future<Map<String, dynamic>> getChallenges() => request(
    'GET',
    '/api/challenges',
  );
}
