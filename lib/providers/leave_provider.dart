import 'package:flutter/material.dart';
import '../services/leave_service.dart';
import '../services/supabase_service.dart';

class LeaveProvider extends ChangeNotifier {
  final LeaveService _service = LeaveService();
  List<Map<String, dynamic>> myLeaves = [];
  List<Map<String, dynamic>> todayLeaves = [];
  List<Map<String, dynamic>> allLeaves = [];
  bool isLoading = false;
  String? error;

  double _remainAnnual = 0;
  double get remainAnnual => _remainAnnual;

  double _currentGrantedAnnual = 0;
  double get currentGrantedAnnual => _currentGrantedAnnual;

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

  Map<String, dynamic>? _employee;
  Map<String, dynamic>? get employee => _employee;

  void setEmployee(Map<String, dynamic>? employee) {
    _employee = employee;
    notifyListeners();
  }

  Future<void> fetchMyLeaves({required String email}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      myLeaves = await _service.fetchMyLeavesRaw(email);
      _remainAnnual = (await calculateRemainAnnual(email)).toDouble();
      _currentGrantedAnnual = (await calculateGrantedAnnual(email)).toDouble();
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

  Future<void> fetchAllLeaves() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      allLeaves = await _service.fetchAllLeavesRaw();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 법정 연차 지급 공식 반영 (1년차 월차, 2년차 15+미사용, 3년차~ 2년마다 1개 추가)
  Future<double> calculateRemainAnnual(String userEmail) async {
    final supabaseService = SupabaseService();
    final employee = await supabaseService.getEmployeeByEmail(userEmail);
    if (employee == null || employee['hire_date'] == null) return 0;
    final DateTime hireDate = DateTime.parse(employee['hire_date']);
    final now = DateTime.now();
    final int yearsOfService = (now.year - hireDate.year) + 1;
    double totalAnnual = 0;
    if (yearsOfService == 1) {
      // 1년차: 월차(최대 11개)
      int months = (now.year - hireDate.year) * 12 + (now.month - hireDate.month);
      if (now.day < hireDate.day) months--;
      totalAnnual = months.clamp(0, 11).toDouble();
    } else {
      // 2년차: 15 + 1년차 미사용 월차, 3년차~: 15 + ((근속년수-2)~/2)
      int add = ((yearsOfService - 2) ~/ 2); // 3년차부터 2년마다 1개 추가
      totalAnnual = (15 + add).toDouble();
      // 2년차에만 1년차 미사용 월차 이월
      if (yearsOfService == 2) {
        int months = 11;
        double usedInFirstYear = 0;
        for (final l in myLeaves) {
          final leaveDate = DateTime.parse(l['start_date']);
          if (l['status'] == 'approved' && leaveDate.isAfter(hireDate) && leaveDate.isBefore(hireDate.add(Duration(days: 365)))) {
            if (l['type'] == 'annual') {
              usedInFirstYear += ((DateTime.parse(l['end_date']).difference(DateTime.parse(l['start_date'])).inDays) + 1) * 1.0;
            } else if (l['type'] == 'halfAm' || l['type'] == 'half_am' || l['type'] == 'halfPm' || l['type'] == 'half_pm') {
              usedInFirstYear += 0.5;
            }
          }
        }
        int unusedFirstYear = months - usedInFirstYear.round();
        if (unusedFirstYear > 0) totalAnnual += unusedFirstYear.toDouble();
      }
    }

    // 전체 사용 연차 차감
    double used = 0;
    for (final l in myLeaves) {
      if (l['status'] == 'approved') {
        if (l['type'] == 'annual') {
          used += ((DateTime.parse(l['end_date']).difference(DateTime.parse(l['start_date'])).inDays) + 1) * 1.0;
        } else if (l['type'] == 'halfAm' || l['type'] == 'half_am' || l['type'] == 'halfPm' || l['type'] == 'half_pm') {
          used += 0.5;
        }
      }
    }
    return (totalAnnual - used).clamp(0, totalAnnual);
  }

  // 현재 지급 연차(법정 지급 공식, 사용 차감 전)
  Future<double> calculateGrantedAnnual(String userEmail) async {
    final supabaseService = SupabaseService();
    final employee = await supabaseService.getEmployeeByEmail(userEmail);
    if (employee == null || employee['hire_date'] == null) return 0.0;
    final DateTime hireDate = DateTime.parse(employee['hire_date']);
    final now = DateTime.now();
    final int yearsOfService = (now.year - hireDate.year) + 1;
    double totalAnnual = 0;
    if (yearsOfService == 1) {
      int months = (now.year - hireDate.year) * 12 + (now.month - hireDate.month);
      if (now.day < hireDate.day) months--;
      totalAnnual = months.clamp(0, 11).toDouble();
    } else {
      int add = ((yearsOfService - 2) ~/ 2);
      totalAnnual = (15 + add).toDouble();
      if (yearsOfService == 2) {
        int months = 11;
        double usedInFirstYear = 0;
        for (final l in myLeaves) {
          final leaveDate = DateTime.parse(l['start_date']);
          if (l['status'] == 'approved' && leaveDate.isAfter(hireDate) && leaveDate.isBefore(hireDate.add(Duration(days: 365)))) {
            if (l['type'] == 'annual') {
              usedInFirstYear += ((DateTime.parse(l['end_date']).difference(DateTime.parse(l['start_date'])).inDays) + 1) * 1.0;
            } else if (l['type'] == 'halfAm' || l['type'] == 'half_am' || l['type'] == 'halfPm' || l['type'] == 'half_pm') {
              usedInFirstYear += 0.5;
            }
          }
        }
        int unusedFirstYear = months - usedInFirstYear.round();
        if (unusedFirstYear > 0) totalAnnual += unusedFirstYear.toDouble();
      }
    }
    return totalAnnual;
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
      await fetchMyLeaves(email: userEmail);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 특정 연도 지급연차 계산 (법정 공식)
  double getGrantedAnnualForYear(int year) {
    final employeeData = _employee;
    if (employeeData == null || employeeData['hire_date'] == null) return 0.0;
    final hireDate = DateTime.parse(employeeData['hire_date']);
    if (year == hireDate.year) {
      int months = (year - hireDate.year) * 12 + (1 - hireDate.month);
      return months.clamp(0, 11).toDouble();
    } else {
      final yearsOfService = (year - hireDate.year) + 1;
      return (15 + ((yearsOfService - 2) ~/ 2)).toDouble();
    }
  }

  Future<void> updateLeaveStatus(int id, String status) async {
    await _service.updateLeaveStatus(id, status);
    await fetchAllLeaves();
  }
} 