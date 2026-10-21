import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/goals_api.dart';

class GoalsProvider extends ChangeNotifier {
  final ApiService api;
  GoalsProvider(this.api);

  List<Map<String, dynamic>> goals = [];
  bool loading = false;
  String? error;

  List<Map<String, dynamic>> get active =>
      goals.where((g) => g['status'] != 'completed').toList();
  List<Map<String, dynamic>> get completed =>
      goals.where((g) => g['status'] == 'completed').toList();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      goals = await api.listGoals();
    } on ApiException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<String?> create({
    required String title,
    required String metric,
    required double targetValue,
    String? unit,
    String? endDate,
  }) async {
    try {
      final goal = await api.createGoal(
        title: title,
        metric: metric,
        targetValue: targetValue,
        unit: unit,
        endDate: endDate,
      );
      goals = [...goals, goal];
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> update(int id, Map<String, dynamic> patch) async {
    try {
      final updated = await api.updateGoal(id, patch);
      goals = goals.map((g) => g['id'] == id ? updated : g).toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> adjust(int id, double delta) async {
    final goal = goals.firstWhere((g) => g['id'] == id);
    final next = ((goal['current_value'] as num?)?.toDouble() ?? 0) + delta;
    return update(id, {
      'current_value': next < 0 ? 0 : next,
    });
  }

  Future<String?> setStatus(int id, String status) =>
      update(id, {'status': status});

  Future<String?> remove(int id) async {
    try {
      await api.deleteGoal(id);
      goals = goals.where((g) => g['id'] != id).toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
