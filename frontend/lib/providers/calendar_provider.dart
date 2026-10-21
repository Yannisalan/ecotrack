import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/error_messages.dart';
import '../services/stats_api.dart';

String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

class CalendarProvider extends ChangeNotifier {
  final ApiService api;
  CalendarProvider(this.api, {DateTime? initialMonth})
    : month = initialMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  DateTime month;
  List<Map<String, dynamic>> days = [];
  bool loading = false;
  String? error;

  String get monthKeyValue => monthKey(month);
  String get monthLabel => '${_monthNames[month.month - 1]} ${month.year}';

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.getCalendar(monthKeyValue);
      days = (data['days'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      error = friendlyError(e);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> previousMonth() async {
    month = DateTime(month.year, month.month - 1);
    await load();
  }

  Future<void> nextMonth() async {
    month = DateTime(month.year, month.month + 1);
    await load();
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
