import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/responsive_utils.dart';

class AttendanceStatisticsWidget extends StatefulWidget {
  const AttendanceStatisticsWidget({super.key});

  @override
  State<AttendanceStatisticsWidget> createState() =>
      _AttendanceStatisticsWidgetState();
}

class _AttendanceStatisticsWidgetState extends State<AttendanceStatisticsWidget> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // 통계 데이터
  int _totalCount = 0;
  int _normalCount = 0;
  int _lateCount = 0;
  int _absentCount = 0;
  int _leaveCount = 0;
  
  // 상세 명단
  List<Map<String, dynamic>> _lateEmployees = [];
  List<Map<String, dynamic>> _absentEmployees = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 오늘자 출근 기록 조회
      final attendanceRecords = await _supabase
          .from('attendance_records')
          .select('*')
          .eq('date', todayStr);

      // 오늘 휴가/출장자 조회 (RPC 함수 실패시 기존 방식으로 폴백)
      List<dynamic> allLeaves;
      try {
        allLeaves = await _supabase
            .rpc('get_all_approved_leaves_for_stats');
      } catch (e) {
        // RPC 함수 실패시 기존 방식으로 폴백
        allLeaves = await _supabase
            .from('leave')
            .select('*')
            .eq('status', 'approved');
      }

      // 오늘 날짜에 해당하는 휴가 필터링
      final todayLeaves = <Map<String, dynamic>>[];
      for (var leave in allLeaves) {
        final startDate = DateTime.parse(leave['start_date']);
        final endDate = DateTime.parse(leave['end_date']);
        final todayDate = DateTime.parse(todayStr);

        if (startDate.isBefore(todayDate.add(Duration(days: 1))) &&
            endDate.isAfter(todayDate.subtract(Duration(days: 1)))) {
          todayLeaves.add(leave);
        }
      }

      // 휴가/출장자 이메일 목록
      final leaveEmails = todayLeaves
          .map((l) => l['user_email']?.toString().toLowerCase())
          .where((email) => email != null)
          .toSet();

      // 통계 계산
      int normal = 0;
      int late = 0;
      int absent = 0;
      final lateList = <Map<String, dynamic>>[];
      final absentList = <Map<String, dynamic>>[];

      for (var record in attendanceRecords) {
        final email = record['user_email']?.toString().toLowerCase();
        final status = record['status']?.toString();
        final clockIn = record['clock_in'];
        final name = record['employee_name']?.toString() ?? '알 수 없음';
        
        // 휴가/출장자는 제외
        if (email != null && leaveEmails.contains(email)) {
          continue;
        }

        // 오후반차는 휴가로 카운트
        if (status == '오후반차') {
          continue;
        }

        // 미출근 체크
        if (clockIn == null || status == '미출근') {
          absent++;
          absentList.add({'name': name});
          continue;
        }

        // 정상/지각 구분
        if (status == '출근' || status == '정상 출근') {
          normal++;
        } else if (status == '지각') {
          late++;
          lateList.add({
            'name': name,
            'time': clockIn.toString(),
          });
        } else if (status == '오전반차' && clockIn != null) {
          // 오전반차 후 출근 시간 체크
          try {
            final timeParts = clockIn.toString().split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            
            if (hour > 13 || (hour == 13 && minute > 30)) {
              late++;
              lateList.add({
                'name': name,
                'time': clockIn.toString(),
              });
            } else {
              normal++;
            }
          } catch (e) {
            normal++;
          }
        } else if (clockIn != null) {
          // clock_in 시간으로 판단
          try {
            final timeParts = clockIn.toString().split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            
            if (hour > 8 || (hour == 8 && minute > 30)) {
              late++;
              lateList.add({
                'name': name,
                'time': clockIn.toString(),
              });
            } else {
              normal++;
            }
          } catch (e) {
            normal++;
          }
        }
      }

      // 반차 카운트
      int halfDayCount = 0;
      for (var record in attendanceRecords) {
        final status = record['status']?.toString();
        if (status == '오전반차' && record['clock_in'] == null) {
          halfDayCount++;
        } else if (status == '오후반차') {
          halfDayCount++;
        }
      }

      // 전체 인원은 정상 + 지각 + 미출근 + 연차/출장의 합
      final actualLeaveCount = todayLeaves.length + halfDayCount;
      final actualTotalCount = normal + late + absent + actualLeaveCount;
      
      setState(() {
        _totalCount = actualTotalCount;
        _normalCount = normal;
        _lateCount = late;
        _absentCount = absent;
        _leaveCount = actualLeaveCount;
        _lateEmployees = lateList;
        _absentEmployees = absentList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final attendanceRole = userProvider.employee?['attendance_role'];
    final hasManagerRole = attendanceRole != null && 
        attendanceRole is List && 
        (attendanceRole).isNotEmpty;

    if (_isLoading) {
      return Container(
        margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 20)),
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 16)),
          boxShadow: AppShadows.cardShadow,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
        boxShadow: AppShadows.cardShadow,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
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
          
          // 통계 표시
          Padding(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('전체', _totalCount, const Color(0xFF1777CB)),
                _buildStatItem('정상', _normalCount, const Color(0xFF4CAF50)),
                _buildStatItem('지각', _lateCount, const Color(0xFFE57373)),
                _buildStatItem('미출근', _absentCount, const Color(0xFFE57373)),
                _buildStatItem('연차/출장', _leaveCount, const Color(0xFF7E57C2)),
              ],
            ),
          ),

          if (hasManagerRole && _lateEmployees.isNotEmpty) ...[
            const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: const Color(0xFFE57373),
                        size: 16,
                      ),
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
                    children: _lateEmployees.map((emp) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 10),
                          vertical: ResponsiveUtils.spacing(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 6),
                          ),
                        ),
                        child: Text(
                          '${emp['name']} (${emp['time']})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF424242),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          if (_absentEmployees.isNotEmpty) ...[
            const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: const Color(0xFFE57373),
                        size: 16,
                      ),
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
                    children: _absentEmployees.map((emp) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 10),
                          vertical: ResponsiveUtils.spacing(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 6),
                          ),
                        ),
                        child: Text(
                          emp['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF424242),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
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