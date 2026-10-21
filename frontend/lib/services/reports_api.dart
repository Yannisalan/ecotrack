import 'api_service.dart';

extension ReportsApi on ApiService {
  /// CSV export of the user's activities for the rolling [period]
  /// ('week' or 'month').
  Future<String> getActivitiesCsv(String period) => requestText(
    'GET',
    '/api/reports/activities.csv',
    query: {'period': period},
  );

  /// One-page PDF summary for the rolling [period].
  Future<List<int>> getSummaryPdf(String period) => requestBytes(
    'GET',
    '/api/reports/summary.pdf',
    query: {'period': period},
  );
}
