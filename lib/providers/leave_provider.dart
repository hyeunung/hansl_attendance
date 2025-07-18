import 'package:flutter/material.dart';
import '../services/leave_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../constants/app_strings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      
      // 서버에서 연차 계산 후 DB 값 가져오기
      await _calculateAndUpdateAnnualLeave(email);
      await _loadAnnualLeaveFromDB(email);
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

  // 서버에서 연차 계산 (Edge Function 호출)
  Future<void> _calculateAndUpdateAnnualLeave(String userEmail) async {
    try {
      const projectId = 'qvhbigvdfyvhoegkhvef';
      final functionUrl = 'https://$projectId.supabase.co/functions/v1/calculate_annual_leave';
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'userEmail': userEmail,
          'targetYear': DateTime.now().year,
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('✅ 서버 연차 계산 완료: ${responseData['data']}');
        } else {
          print('❌ 서버 연차 계산 실패: ${responseData['error']}');
        }
      } else {
        print('❌ Edge Function 호출 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ 연차 계산 중 오류: $e');
      // 연차 계산 실패는 전체 프로세스를 중단시키지 않음
    }
  }

  // DB에서 계산된 연차 정보 로드
  Future<void> _loadAnnualLeaveFromDB(String userEmail) async {
    try {
      final supabaseService = SupabaseService();
      final employee = await supabaseService.getEmployeeByEmail(userEmail);
      
      if (employee != null) {
        _currentGrantedAnnual = (employee['annual_leave_granted_current_year'] ?? 0).toDouble();
        _remainAnnual = double.tryParse(employee['remaining_annual_leave']?.toString() ?? '0') ?? 0.0;
        
        print('📊 DB에서 로드된 연차 정보: 지급=${_currentGrantedAnnual}, 잔여=${_remainAnnual}');
      }
    } catch (e) {
      print('❌ DB 연차 정보 로드 실패: $e');
      // 기본값 유지
      _currentGrantedAnnual = 0;
      _remainAnnual = 0;
    }
  }

  // 특정 연도 지급연차 조회 (DB에서)
  double getGrantedAnnualForYear(int year) {
    // 현재는 현재 연도만 지원, 향후 확장 가능
    if (year == DateTime.now().year) {
      return _currentGrantedAnnual;
    }
    return 0.0;
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
      // employees DB에서 name과 department 조회
      final supabaseService = SupabaseService();
      final employee = await supabaseService.getEmployeeByEmail(userEmail);
      final name = employee?['name'] ?? '';
      final department = employee?['department'] ?? '';
      
      // DB에 연차/출장 신청 저장
      await _service.insertLeave({
        'user_email': userEmail,
        'name': name,
        'type': type,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // 푸시 알림 전송 (Manager/일반직원 구분)
      try {
        final typeLabel = _getTypeLabel(type);
        final period = _formatPeriod(startDate, endDate);
        
        // 신청자 구분: Manager / Admin / 일반직원
        final isManager = AppStrings.managerNames.contains(name);
        final isAdmin = userEmail == AppStrings.adminEmail;
        
        if (isAdmin) {
          // Admin 신청 → 아무에게도 알림 안함 (혼자 처리)
          print('👑 Admin 신청이므로 알림 전송 생략: $name님의 $typeLabel 신청');
        } else if (isManager) {
          // Manager 신청 → Admin에게만 알림
          await NotificationService.sendNotificationToAdmins(
            title: '👑 Manager $typeLabel 신청',
            body: '$name 매니저님이 $typeLabel을 신청했습니다.\n기간: $period',
            data: {
              'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
              'requester_email': userEmail,
              'requester_name': name,
              'start_date': startDate.toIso8601String().substring(0, 10),
              'end_date': endDate.toIso8601String().substring(0, 10),
              'leave_type': type,
              'requester_is_manager': 'true',
            },
            requesterDepartment: department,
            requesterEmail: userEmail,
            isManagerRequest: true, // Manager 신청임을 명시
          );
          print('✅ Admin 알림 전송 완료: $name 매니저님의 $typeLabel 신청');
        } else {
          // 일반직원 신청 → 해당 부서 Manager + Admin 둘 다 알림
          await NotificationService.sendNotificationToAdmins(
            title: '📝 새로운 $typeLabel 신청',
            body: '$name님이 $typeLabel을 신청했습니다.\n기간: $period',
            data: {
              'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
              'requester_email': userEmail,
              'requester_name': name,
              'start_date': startDate.toIso8601String().substring(0, 10),
              'end_date': endDate.toIso8601String().substring(0, 10),
              'leave_type': type,
              'requester_is_manager': 'false',
            },
            requesterDepartment: department,
            requesterEmail: userEmail,
            isManagerRequest: false, // 일반직원 신청임을 명시
          );
          print('✅ 부서 관리자 + Admin 알림 전송 완료: $name님의 $typeLabel 신청');
        }
      } catch (notificationError) {
        print('⚠️ 알림 전송 실패: $notificationError');
        // 알림 실패는 전체 프로세스를 중단시키지 않음
      }
      
      await fetchMyLeaves(email: userEmail);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 휴가 타입 라벨 변환 헬퍼 메서드
  String _getTypeLabel(String type) {
    switch (type) {
      case 'annual':
        return '연차';
      case 'half_am':
        return '오전반차';
      case 'half_pm':
        return '오후반차';
      case 'official':
        return '공가';
      case 'biztrip':
        return '출장';
      default:
        return '휴가';
    }
  }

  // 기간 포맷팅 헬퍼 메서드
  String _formatPeriod(DateTime startDate, DateTime endDate) {
    if (startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day) {
      return '${startDate.month}월 ${startDate.day}일';
    } else {
      return '${startDate.month}월 ${startDate.day}일 ~ ${endDate.month}월 ${endDate.day}일';
    }
  }

  Future<void> updateLeaveStatus(int id, String status) async {
    try {
      // 1. 승인/반려하기 전에 해당 신청 정보 조회
      final leaveDetails = allLeaves.firstWhere(
        (leave) => leave['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      
      if (leaveDetails.isEmpty) {
        print('❌ 신청 정보를 찾을 수 없습니다: ID $id');
        return;
      }
      
      final requesterEmail = leaveDetails['user_email'] as String?;
      final requesterName = leaveDetails['name'] as String? ?? '사용자';
      final leaveType = leaveDetails['type'] as String? ?? '';
      final startDate = leaveDetails['start_date'] as String? ?? '';
      final endDate = leaveDetails['end_date'] as String? ?? '';
      
      // 2. 상태 업데이트
      await _service.updateLeaveStatus(id, status);
      
      // 3. 신청자의 연차 정보 재계산 (승인/반려 시)
      if (requesterEmail != null && requesterEmail.isNotEmpty) {
        await _calculateAndUpdateAnnualLeave(requesterEmail);
      }
      
      // 4. 신청자에게 승인/반려 결과 알림 전송
      if (requesterEmail != null && requesterEmail.isNotEmpty) {
        try {
          final typeLabel = _getTypeLabel(leaveType);
          final statusLabel = status == 'approved' ? '승인' : '반려';
          final statusEmoji = status == 'approved' ? '✅' : '❌';
          
          String period = '';
          if (startDate.isNotEmpty && endDate.isNotEmpty) {
            final start = DateTime.parse(startDate);
            final end = DateTime.parse(endDate);
            period = _formatPeriod(start, end);
          }
          
          await NotificationService.sendNotificationToUser(
            userEmail: requesterEmail,
            title: '$statusEmoji $typeLabel $statusLabel',
            body: '$requesterName님의 $typeLabel 신청이 ${statusLabel}되었습니다.${period.isNotEmpty ? '\n기간: $period' : ''}',
            data: {
              'type': 'leave_result',
              'leave_id': id.toString(),
              'status': status,
              'leave_type': leaveType,
              'start_date': startDate,
              'end_date': endDate,
            },
          );
          print('✅ 신청자 알림 전송 완료: $requesterName님에게 $typeLabel $statusLabel 알림');
        } catch (notificationError) {
          print('⚠️ 신청자 알림 전송 실패: $notificationError');
          // 알림 실패는 전체 프로세스를 중단시키지 않음
        }
      }
      
      // 5. 목록 새로고침
      await fetchAllLeaves();
    } catch (e) {
      print('❌ 승인/반려 처리 실패: $e');
      rethrow;
    }
  }
} 