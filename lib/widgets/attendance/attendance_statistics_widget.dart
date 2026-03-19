import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

class AttendanceStatisticsWidget extends StatefulWidget {
  final Function(bool isNonWorkingDay)? onWorkingDayStatusChanged;

  const AttendanceStatisticsWidget({
    super.key,
    this.onWorkingDayStatusChanged,
  });

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

  // 주말/공휴일 관련
  bool _isNonWorkingDay = false;
  bool _lateExpanded = false;
  bool _absentExpanded = false;
  String? _holidayName;

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

      // 주말 체크 (토요일: 6, 일요일: 7)
      final isWeekend = today.weekday >= 6;

      // 공휴일 체크
      final holiday = await _supabase
          .from('holidays')
          .select('name')
          .eq('date', todayStr)
          .maybeSingle();
      final isHoliday = holiday != null;

      // 주말 또는 공휴일인 경우 특별 처리
      if (isWeekend || isHoliday) {
        String dayType;
        if (isWeekend && isHoliday && holiday != null) {
          dayType = holiday['name'] as String; // 공휴일 이름 우선
        } else if (isWeekend) {
          dayType = today.weekday == 6 ? '토요일' : '일요일';
        } else if (holiday != null) {
          dayType = holiday['name'] as String;
        } else {
          dayType = '휴일';
        }

        setState(() {
          _isNonWorkingDay = true;
          _holidayName = dayType;
          _isLoading = false;
        });

        // 부모 위젯에 휴일 상태 전달
        widget.onWorkingDayStatusChanged?.call(true);
        return;
      }

      // 오늘자 출근 기록 조회
      final attendanceRecords = await _supabase
          .from('attendance_records')
          .select('*')
          .eq('date', todayStr);

      // 재직자 이메일 조회 (is_active = true)
      final activeEmployees = await _supabase
          .from('employees')
          .select('email')
          .eq('is_active', true);
      final activeEmails = activeEmployees
          .map((e) => e['email']?.toString().toLowerCase())
          .where((email) => email != null)
          .toSet();

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

        // 재직자만 통계 대상
        if (email == null || !activeEmails.contains(email)) {
          continue;
        }

        // 휴가/출장자는 제외
        if (leaveEmails.contains(email)) {
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

      if (!mounted) return;
      setState(() {
        _isNonWorkingDay = false;
        _holidayName = null;
        _totalCount = actualTotalCount;
        _normalCount = normal;
        _lateCount = late;
        _absentCount = absent;
        _leaveCount = actualLeaveCount;
        _lateEmployees = lateList;
        _absentEmployees = absentList;
        _isLoading = false;
      });

      // 부모 위젯에 근무일 상태 전달
      widget.onWorkingDayStatusChanged?.call(false);
    } catch (e) {
      if (!mounted) return;
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
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 주말/공휴일인 경우 특별한 UI 표시
    if (_isNonWorkingDay) {
      return _buildNonWorkingDayWidget();
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 섹션 헤더 (회색 배경)
          const FlatSectionHeader(title: '오늘 출근 현황'),

          // 통계 요약 행 (5칸 그리드)
          FlatStatGrid(
            items: [
              FlatStatItem(label: '전체', value: _totalCount.toString(), color: AppColors.textPrimary),
              FlatStatItem(label: '정상', value: _normalCount.toString(), color: AppColors.success),
              FlatStatItem(label: '지각', value: _lateCount.toString(), color: AppColors.late_),
              FlatStatItem(label: '미출근', value: _absentCount.toString(), color: AppColors.warning),
              FlatStatItem(label: '연차/출장', value: _leaveCount.toString(), color: AppColors.purple),
            ],
          ),

          // 지각 직원 (토글)
          if (hasManagerRole && _lateEmployees.isNotEmpty)
            FlatToggleSection(
              title: '지각 ${_lateEmployees.length}명',
              icon: Icons.access_time,
              color: AppColors.late_,
              isExpanded: _lateExpanded,
              onTap: () => setState(() => _lateExpanded = !_lateExpanded),
              children: [
                FlatTableColumnHeader(
                  columns: [
                    const FlatColumn(label: '이름', flex: 3),
                    const FlatColumn(label: '출근시간', flex: 2, align: TextAlign.center),
                  ],
                  trailingWidth: 60,
                ),
                ..._lateEmployees.map((emp) => FlatTableRow(
                  cells: [
                    Text(emp['name'] ?? '-', style: AppTextStyles.tableCell(context)),
                    Text(emp['time'] ?? '-', textAlign: TextAlign.center, style: AppTextStyles.tableCellSub(context)),
                  ],
                  flexValues: const [3, 2],
                  trailing: StatusChip(label: '지각', color: AppColors.late_),
                )),
              ],
            ),

          // 미출근 직원 (토글)
          if (_absentEmployees.isNotEmpty)
            FlatToggleSection(
              title: '미출근 ${_absentEmployees.length}명',
              icon: Icons.cancel_outlined,
              color: AppColors.warning,
              isExpanded: _absentExpanded,
              onTap: () => setState(() => _absentExpanded = !_absentExpanded),
              children: [
                ..._absentEmployees.map((emp) => FlatTableRow(
                  cells: [
                    Text(emp['name'] ?? '-', style: AppTextStyles.tableCell(context)),
                    Text('—', textAlign: TextAlign.center, style: AppTextStyles.tableCellSub(context)),
                  ],
                  flexValues: const [3, 2],
                  trailing: StatusChip(label: '미출근', color: AppColors.warning),
                )),
              ],
            ),
        ],
      ),
    );
  }

  // 주말/공휴일용 위젯
  Widget _buildNonWorkingDayWidget() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const FlatSectionHeader(title: '오늘 출근 현황'),
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 32)),
            child: Column(
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: ResponsiveUtils.spacing(context, 40),
                  color: AppColors.gray400,
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                Text(
                  '오늘은 근무일이 아닙니다',
                  style: AppTextStyles.sectionSubtitle(context),
                ),
                if (_holidayName != null) ...[
                  SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                  Text(
                    _holidayName!,
                    style: AppTextStyles.emptyState(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
