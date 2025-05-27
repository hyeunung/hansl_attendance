import 'package:flutter/material.dart';
import '../services/leave_service.dart';
import '../services/supabase_service.dart';

class LeaveProvider extends ChangeNotifier {
  final LeaveService _service = LeaveService();
  List<Map<String, dynamic>> myLeaves = [];
  List<Map<String, dynamic>> todayLeaves = [];
  bool isLoading = false;
  String? error;

  // 잔여 연차 계산 (예시: type == 'annual'/'halfAm'/'halfPm', status == 'approved'만 차감)
  int get remainAnnual {
    // 지급 연차는 예시로 15개(실제는 입사일 등으로 계산 필요)
    const int totalAnnual = 15;
    double used = 0;
    for (final l in myLeaves) {
      if (l['status'] == 'approved') {
        if (l['type'] == 'annual') {
          used += ((DateTime.parse(l['end_date']).difference(DateTime.parse(l['start_date'])).inDays) + 1) * 1.0;
        } else if (l['type'] == 'halfAm' || l['type'] == 'halfPm') {
          used += 0.5;
        }
      }
    }
    return (totalAnnual - used).clamp(0, totalAnnual).toInt();
  }

  // 대기 중 신청 개수
  int get pendingCount => myLeaves.where((l) => l['status'] == 'pending').length;

  // 출장 일수(approved만)
  int get biztripDays {
    int days = 0;
    for (final l in myLeaves) {
      if (l['status'] == 'approved' && l['type'] == 'biztrip') {
        days += (DateTime.parse(l['end_date']).difference(DateTime.parse(l['start_date'])).inDays) + 1;
      }
    }
    return days;
  }

  // 최근 신청(최신순 5개)
  List<Map<String, dynamic>> get recentLeaves {
    final sorted = [...myLeaves];
    sorted.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    return sorted.take(5).toList();
  }

  Future<void> fetchMyLeaves(String userEmail) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      myLeaves = await _service.fetchMyLeavesRaw(userEmail);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodayLeaves(DateTime today) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      todayLeaves = await _service.fetchTodayLeavesRaw(today);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 연차/출장 신청
  Future<void> requestLeave({
    required String userEmail,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      // employees DB에서 name 조회
      final supabaseService = SupabaseService();
      final name = await supabaseService.getEmployeeNameByEmail(userEmail);
      await _service.insertLeave({
        'user_email': userEmail,
        'name': name ?? '',
        'type': type,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      await fetchMyLeaves(userEmail);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
} 