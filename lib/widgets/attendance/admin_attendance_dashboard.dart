import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../utils/responsive_utils.dart';

class AdminAttendanceDashboard extends StatefulWidget {
  const AdminAttendanceDashboard({super.key});

  @override
  State<AdminAttendanceDashboard> createState() => _AdminAttendanceDashboardState();
}

class _AdminAttendanceDashboardState extends State<AdminAttendanceDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _attendanceSummary = {};
  List<Map<String, dynamic>> _lateEmployees = [];
  List<Map<String, dynamic>> _absentEmployees = [];

  @override
  void initState() {
    super.initState();
    _loadAttendanceSummary();
    _subscribeToRealtimeUpdates();
  }

  @override
  void dispose() {
    _supabase.removeAllChannels();
    super.dispose();
  }

  Future<void> _loadAttendanceSummary() async {
    try {
      setState(() => _isLoading = true);

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      if (kDebugMode) print('🔍 오늘 날짜: $todayStr');

      // RPC 사용하지 않고 직접 계산 (휴가/출장자 제외 로직 적용을 위해)
      // 서버 집계(RPC)로 오늘 요약 가져오기 - 비활성화
      /*
      try {
        final summary = await _supabase.rpc('attendance_summary_today');
        if (kDebugMode) {
          print('🧮 RPC attendance_summary_today 결과: $summary');
        }
        if (summary is Map<String, dynamic>) {
          // RPC 결과는 휴가/출장자를 제외하지 않으므로 사용하지 않음
        }
      } catch (e) {
        if (kDebugMode) print('❌ RPC attendance_summary_today 호출 실패: $e');
      }
      */

      // 오늘자 시드된 출근 레코드 조회 (전체 필드 조회로 RLS 우회)
      List<dynamic> allTodayRecords = [];
      try {
        allTodayRecords = await _supabase
            .from('attendance_records')
            .select('*')  // 모든 필드를 가져와야 RLS가 정상 작동
            .eq('date', todayStr);
        if (kDebugMode) {
          print('👥 오늘자 전체 레코드: ${allTodayRecords.length}건');
          if (allTodayRecords.isNotEmpty) {
            print('  첫 번째 레코드 키: ${allTodayRecords[0].keys.toList()}');
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ 오늘자 레코드 조회 에러: $e');
      }

      // 오늘 휴가자 조회 - 단순화된 쿼리
      List<dynamic> onLeave = [];
      List<dynamic> onBusinessTrip = [];
      
      try {
        // 모든 승인된 휴가 조회
        final allLeaves = await _supabase
            .from('leave')
            .select('*')
            .eq('status', 'approved');
        
        if (kDebugMode) {
          print('📅 전체 휴가 조회: ${allLeaves.length}건');
        }
        
        // 오늘 날짜에 해당하는 휴가 필터링
        for (var leave in allLeaves) {
          final startDate = DateTime.parse(leave['start_date']);
          final endDate = DateTime.parse(leave['end_date']);
          final todayDate = DateTime.parse(todayStr);
          
          if (startDate.isBefore(todayDate.add(Duration(days: 1))) && 
              endDate.isAfter(todayDate.subtract(Duration(days: 1)))) {
            
            final leaveType = (leave['type'] ?? '').toString();
            if (leaveType == 'biztrip' || leaveType == '출장') {
              onBusinessTrip.add(leave);
            } else {
              onLeave.add(leave);
            }
            
            if (kDebugMode) {
              print('  - 오늘 휴가/출장: user_email=${leave['user_email']}, type=${leave['type']}');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ 휴가 조회 에러: $e');
      }

      // 휴가자/출장자 식별 세트 생성 (이메일 + 이름 기준 모두)
      final leaveEmployeeEmails = (onLeave as List)
          .map((l) => l['user_email']?.toString().trim().toLowerCase())
          .where((email) => email != null)
          .cast<String>()
          .toList();
      final businessTripEmployeeEmails = (onBusinessTrip as List)
          .map((l) => l['user_email']?.toString().trim().toLowerCase())
          .where((email) => email != null)
          .cast<String>()
          .toList();
      final allAbsentEmployeeEmails = <String>{
        ...leaveEmployeeEmails,
        ...businessTripEmployeeEmails,
      };

      // 이름 세트 (user_email이 null인 레코드 대비)
      final leaveNames = (onLeave as List)
          .map((l) => l['name']?.toString().trim().toLowerCase())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();
      final businessTripNames = (onBusinessTrip as List)
          .map((l) => l['name']?.toString().trim().toLowerCase())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();
      final allAbsentNames = <String>{
        ...leaveNames,
        ...businessTripNames,
      };

      // 오늘 출근 기록은 위 allTodayRecords를 그대로 활용 (중복 쿼리 제거)
      List<dynamic> attendanceRecords = List<dynamic>.from(allTodayRecords);

      // 정상 출근 (8시 30분 이전 또는 status가 '출근'), 지각 (8시 30분 이후 또는 status가 '지각') 구분
      final List<Map<String, dynamic>> normalList = [];
      final List<Map<String, dynamic>> lateList = [];
      
      // 직원 맵 의존 제거: 기록 자체의 이름을 사용
      
      for (var record in attendanceRecords) {
        // status 우선 처리: 기존 규칙과 clock_in 보조
        final status = record['status']?.toString();
        
        // 오후반차인 경우는 정상/지각 카운트에서 제외
        if (status == '오후반차') {
          // 오후반차는 휴가로 처리되므로 정상/지각 리스트에 추가하지 않음
          continue;
        }
        
        // 정상 출근 또는 오전반차 후 출근한 경우
        if (status == '출근' || status == '정상 출근') {
          normalList.add({
            'name': record['employee_name']?.toString() ?? '알 수 없음',
            'department': '-',
            'check_in_time': record['clock_in']?.toString() ?? '-',
          });
          continue;
        }
        if (status == '지각') {
          lateList.add({
            'name': record['employee_name']?.toString() ?? '알 수 없음',
            'department': '-',
            'check_in_time': record['clock_in']?.toString() ?? '-',
          });
          continue;
        }
        
        // 오전반차인데 clock_in이 있으면 출근한 것으로 처리
        if (status == '오전반차' && record['clock_in'] != null) {
          // 오전반차 직원이 출근한 경우 정상/지각 판단
          String clockInStr = record['clock_in'].toString();
          try {
            if (clockInStr.contains(':')) {
              final timeParts = clockInStr.split(':');
              final hour = int.tryParse(timeParts[0]) ?? 0;
              final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
              
              // 13:30 이후는 오전반차 지각
              if (hour > 13 || (hour == 13 && minute > 30)) {
                lateList.add({
                  'name': record['employee_name']?.toString() ?? '알 수 없음',
                  'department': '-',
                  'check_in_time': record['clock_in']?.toString() ?? '-',
                });
              } else {
                normalList.add({
                  'name': record['employee_name']?.toString() ?? '알 수 없음',
                  'department': '-',
                  'check_in_time': record['clock_in']?.toString() ?? '-',
                });
              }
              continue;
            }
          } catch (e) {
            if (kDebugMode) {
              print('  ❌ 오전반차 시간 파싱 에러: $e');
            }
          }
        }
        
        if (record['clock_in'] == null) continue;
        
        if (kDebugMode) {
          print('🔍 출근 기록 처리: user_email=${record['user_email']}, clock_in=${record['clock_in']}');
        }
        
        // clock_in이 time 타입인 경우 처리
        String clockInStr = record['clock_in'].toString();
        DateTime checkInTime;
        
        try {
          // HH:mm[:ss] 형식 일반 처리 (문자열 파싱 의존 줄이기)
          if (clockInStr.contains(':')) {
            final timeParts = clockInStr.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
            final second = int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0;
            checkInTime = DateTime(
              today.year,
              today.month,
              today.day,
              hour,
              minute,
              second,
            );
            if (kDebugMode) {
              print('  ⏰ 출근 시간 파싱: $clockInStr -> ${hour}시 ${minute}분 ${second}초');
            }
          } else {
            // ISO 형식 보조 처리
            checkInTime = DateTime.parse('${todayStr}T${record['clock_in']}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('  ❌ 시간 파싱 에러: $e, clock_in=${record['clock_in']}');
          }
          continue;
        }
        
        // 기록의 이름 직접 사용
        final attendanceInfo = {
          'name': record['employee_name']?.toString() ?? '알 수 없음',
          'department': '-',
          'check_in_time': record['clock_in'].toString(),
        };
        
        // 8시 30분 이후는 지각
        if (checkInTime.hour > 8 || (checkInTime.hour == 8 && checkInTime.minute > 30)) {
          lateList.add(attendanceInfo);
          if (kDebugMode) {
            print('  ➡️ 지각 처리: ${attendanceInfo['name']} (${checkInTime.hour}:${checkInTime.minute})');
          }
        } else {
          normalList.add(attendanceInfo);
          if (kDebugMode) {
            print('  ➡️ 정상 출근: ${attendanceInfo['name']} (${checkInTime.hour}:${checkInTime.minute})');
          }
        }
      }

      // 출근한 직원 이메일 목록
      final attendedEmployeeEmails = <String>[];
      // normalList와 lateList에 있는 사람들의 이메일 수집
      for (var record in attendanceRecords) {
        if (record['clock_in'] != null && record['user_email'] != null) {
          final email = record['user_email'].toString().trim().toLowerCase();
          attendedEmployeeEmails.add(email);
        }
      }
      // 중복 제거
      final attendedSet = attendedEmployeeEmails.toSet();
      final uniqueAttendedEmails = attendedSet.toList();

      // 휴가/출장 제외한 유효 인원 레코드
      final List<dynamic> effectiveRecords = allTodayRecords.where((rec) {
        final recEmail = rec['user_email']?.toString();
        final normalizedRecEmail = recEmail == null ? null : recEmail.trim().toLowerCase();
        final recName = rec['employee_name']?.toString();
        final normalizedRecName = recName == null ? null : recName.trim().toLowerCase();
        final bool isOnLeave = (normalizedRecEmail != null && allAbsentEmployeeEmails.contains(normalizedRecEmail)) ||
            (normalizedRecName != null && allAbsentNames.contains(normalizedRecName));
        return !isOnLeave;
      }).toList();

      // 미출근자: 휴가/출장 제외한 인원 중 status가 미출근 or 출근 버튼 미누름(clock_in null)
      final List<Map<String, dynamic>> absentEmployeesList = [];
      for (var rec in effectiveRecords) {
        final recStatus = rec['status']?.toString();
        // 오후반차는 미출근에서 제외
        if (recStatus == '오후반차') {
          continue;
        }
        final bool isAbsentByStatus = recStatus == null || recStatus.isEmpty || recStatus == '미출근';
        if (isAbsentByStatus || rec['clock_in'] == null) {
          absentEmployeesList.add({
            'name': rec['employee_name']?.toString() ?? '알 수 없음',
            'department': '-',
          });
        }
      }

      if (kDebugMode) {
        print('\n========== 출근 현황 요약 ==========');
        print('📊 전체 직원 수: ${(allTodayRecords as List).length}명');
        print('✅ 정상 출근: ${normalList.length}명');
        for (var person in normalList) {
          print('   - ${person['name']} (${person['department']}): ${person['check_in_time']}');
        }
        print('⚠️ 지각: ${lateList.length}명');
        for (var person in lateList) {
          print('   - ${person['name']} (${person['department']}): ${person['check_in_time']}');
        }
        print('❌ 미출근 (휴가/출장 제외): ${absentEmployeesList.length}명');
        for (var person in absentEmployeesList) {
          print('   - ${person['name']}');
        }
        print('🏖️ 휴가/출장: ${leaveEmployeeEmails.length + businessTripEmployeeEmails.length}명');
        print('   - 휴가: ${leaveEmployeeEmails.length}명');
        print('   - 출장: ${businessTripEmployeeEmails.length}명');
        print('=====================================\n');
      }

      // 오전반차 아직 출근 안한 직원 + 오후반차 직원 카운트
      int halfAmNotAttendedCount = 0;  // 오전반차인데 아직 출근 안한 직원
      int halfPmCount = 0;  // 오후반차로 변경된 직원
      
      for (var record in attendanceRecords) {
        final status = record['status']?.toString();
        // 오전반차인데 아직 출근 안한 경우 (휴가로 카운트)
        if (status == '오전반차' && record['clock_in'] == null) {
          halfAmNotAttendedCount++;
        }
        // 오후반차인 경우를 카운트 (휴가에 추가)
        if (status == '오후반차') {
          halfPmCount++;
        }
      }
      
      // 실제 휴가/출장 인원 = 연차/출장자 + 오전반차 미출근자 + 오후반차 직원
      // (leave 테이블의 half_am, half_pm은 제외하고 카운트 - 중복 방지)
      final annualAndBizTripCount = (onLeave as List)
          .where((l) => l['type'] != 'half_am' && l['type'] != 'half_pm')
          .length +
          (onBusinessTrip as List).length;
      final actualLeaveCount = annualAndBizTripCount + halfAmNotAttendedCount + halfPmCount;
      
      setState(() {
        _attendanceSummary = {
          // 전체는 오늘자 레코드 전체 인원
          'total': (allTodayRecords as List).length,
          'normal': normalList.length,
          'late': lateList.length,
          'absent': absentEmployeesList.length,
          'leave': actualLeaveCount > 0 ? actualLeaveCount : 0,  // 음수 방지
        };
        _lateEmployees = lateList;
        _absentEmployees = absentEmployeesList.map((e) => {
          'name': e['name'],
          'department': e['department'],
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) print('❌ 출근 현황 조회 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToRealtimeUpdates() {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    _supabase
        .channel('attendance_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'date',
            value: todayStr,
          ),
          callback: (payload) {
            if (kDebugMode) print('📡 실시간 출근 업데이트 감지');
            _loadAttendanceSummary();
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isAdmin = userProvider.employee?['is_admin'] == true;
    final attendanceRole = userProvider.employee?['attendance_role'];
    final isManager = attendanceRole != null && attendanceRole.toString().contains('_manager');

    if (_isLoading) {
      return Container(
        margin: EdgeInsets.only(
          bottom: ResponsiveUtils.spacing(context, 20),
        ),
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 20),
          ),
          boxShadow: [AppShadows.card],
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.spacing(context, 20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 20),
        ),
        boxShadow: [AppShadows.card],
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 16),
              vertical: ResponsiveUtils.spacing(context, 8),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ResponsiveUtils.spacing(context, 20)),
                topRight: Radius.circular(ResponsiveUtils.spacing(context, 20)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.dashboard_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '오늘의 출근 현황',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 요약 통계
          Padding(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '전체',
                  _attendanceSummary['total']?.toString() ?? '0',
                  const Color(0xFF1777CB),
                ),
                _buildStatItem(
                  '정상',
                  _attendanceSummary['normal']?.toString() ?? '0',
                  const Color(0xFF4CAF50),
                ),
                _buildStatItem(
                  '지각',
                  _attendanceSummary['late']?.toString() ?? '0',
                  const Color(0xFFE57373),
                ),
                _buildStatItem(
                  '미출근',
                  _attendanceSummary['absent']?.toString() ?? '0',
                  const Color(0xFFE57373),
                ),
                _buildStatItem(
                  '휴가/출장',
                  _attendanceSummary['leave']?.toString() ?? '0',
                  const Color(0xFF7E57C2),
                ),
              ],
            ),
          ),

          // 지각자 명단 (attendance_role이 비어있지 않은 사용자만 노출)
          if (_lateEmployees.isNotEmpty &&
              attendanceRole is List && (attendanceRole as List).isNotEmpty) ...[
            const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: const Color(0xFFE57373), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '지각 ${_lateEmployees.length}명',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _lateEmployees.map((emp) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 10),
                        vertical: ResponsiveUtils.spacing(context, 6),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                      ),
                      child: Text(
                        '${emp['name']} (${emp['department']}) ${emp['check_in_time']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF424242),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],

          // 미출근자 명단 (전체 사용자에게 노출)
          if (_absentEmployees.isNotEmpty) ...[
            const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: const Color(0xFFE57373), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '미출근 ${_absentEmployees.length}명',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _absentEmployees.map((emp) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 10),
                        vertical: ResponsiveUtils.spacing(context, 6),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                      ),
                      child: Text(
                        '${emp['name']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF424242),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}