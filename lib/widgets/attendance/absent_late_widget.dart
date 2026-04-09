import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/flat_section.dart';

/// 미출근/지각자 위젯 (드롭다운)
class AbsentLateWidget extends StatefulWidget {
  const AbsentLateWidget({super.key});

  @override
  State<AbsentLateWidget> createState() => AbsentLateWidgetState();
}

class AbsentLateWidgetState extends State<AbsentLateWidget> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _lateEmployees = [];
  List<Map<String, dynamic>> _absentEmployees = [];

  bool _lateExpanded = false;
  bool _absentExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 주말/공휴일이면 표시 안 함
      if (today.weekday >= 6) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final holiday = await _supabase
          .from('holidays')
          .select('name')
          .eq('date', todayStr)
          .maybeSingle();
      if (holiday != null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 출근 기록 조회
      final attendanceRecords = await _supabase
          .from('attendance_records')
          .select('*')
          .eq('date', todayStr);

      // 재직자 이메일 (아르바이트 제외)
      final activeEmployees = await _supabase
          .from('employees')
          .select('email')
          .eq('is_active', true)
          .neq('position', '아르바이트');
      final activeEmails = activeEmployees
          .map((e) => e['email']?.toString().toLowerCase())
          .where((email) => email != null)
          .toSet();

      // 오늘 휴가/출장자 조회
      List<dynamic> allLeaves;
      try {
        allLeaves = await _supabase.rpc('get_all_approved_leaves_for_stats');
      } catch (_) {
        allLeaves = await _supabase
            .from('leave')
            .select('*')
            .eq('status', 'approved');
      }

      final todayDate = DateTime.parse(todayStr);
      final leaveEmails = <String>{};
      for (var leave in allLeaves) {
        final startDate = DateTime.parse(leave['start_date']);
        final endDate = DateTime.parse(leave['end_date']);
        if (startDate.isBefore(todayDate.add(const Duration(days: 1))) &&
            endDate.isAfter(todayDate.subtract(const Duration(days: 1)))) {
          final email = leave['user_email']?.toString().toLowerCase();
          if (email != null) leaveEmails.add(email);
        }
      }

      // 미출근/지각 분류
      final lateList = <Map<String, dynamic>>[];
      final absentList = <Map<String, dynamic>>[];

      for (var record in attendanceRecords) {
        final email = record['user_email']?.toString().toLowerCase();
        final status = record['status']?.toString();
        final clockIn = record['clock_in'];
        final name = record['employee_name']?.toString() ?? '알 수 없음';

        if (email == null || !activeEmails.contains(email)) continue;
        if (leaveEmails.contains(email)) continue;
        if (status == '출장' || status == '연차' || status == '공가' || status == '오후반차') continue;

        // 오전반차 미출근
        if (status == '오전반차' && clockIn == null) {
          absentList.add({'name': name, 'isHalfAm': true});
          continue;
        }

        // 미출근
        if (clockIn == null || status == '미출근' || status == '출근 전') {
          absentList.add({'name': name, 'isHalfAm': false});
          continue;
        }

        // 지각
        if (status == '지각') {
          lateList.add({'name': name, 'time': clockIn.toString()});
        } else if (status == '오전반차' && clockIn != null) {
          try {
            final parts = clockIn.toString().split(':');
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            if (h > 13 || (h == 13 && m > 30)) {
              lateList.add({'name': name, 'time': clockIn.toString()});
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _lateEmployees = lateList;
        _absentEmployees = absentList;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? time) {
    if (time == null) return '';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_lateEmployees.isEmpty && _absentEmployees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 지각자
          if (_lateEmployees.isNotEmpty)
            FlatToggleSection(
              title: '지각 ${_lateEmployees.length}명',
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              isExpanded: _lateExpanded,
              onTap: () => setState(() => _lateExpanded = !_lateExpanded),
              children: [
                ..._lateEmployees.map((emp) => FlatTableRow(
                      cells: [
                        Text(emp['name'] ?? '-',
                            style: AppTextStyles.tableCell(context)),
                        Text(_formatTime(emp['time']),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.tableCellSub(context)),
                      ],
                      flexValues: const [3, 2],
                      trailing: StatusChip(
                        label: '지각',
                        color: AppColors.error,
                      ),
                    )),
              ],
            ),

          // 미출근자
          if (_absentEmployees.isNotEmpty)
            FlatToggleSection(
              title: '미출근 ${_absentEmployees.length}명',
              icon: Icons.cancel_outlined,
              color: AppColors.warning,
              isExpanded: _absentExpanded,
              onTap: () => setState(() => _absentExpanded = !_absentExpanded),
              children: [
                ..._absentEmployees.map((emp) {
                  final isHalfAm = emp['isHalfAm'] == true;
                  return FlatTableRow(
                    cells: [
                      Text(emp['name'] ?? '-',
                          style: AppTextStyles.tableCell(context)),
                      Text('—',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.tableCellSub(context)),
                    ],
                    flexValues: const [3, 2],
                    trailing: StatusChip(
                      label: isHalfAm ? '미출근-오전반차' : '미출근',
                      color: isHalfAm ? AppColors.primary : AppColors.warning,
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}
