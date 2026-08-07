import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

class PersonalLateStatistics extends StatefulWidget {
  const PersonalLateStatistics({super.key});

  @override
  State<PersonalLateStatistics> createState() => PersonalLateStatisticsState();
}

class PersonalLateStatisticsState extends State<PersonalLateStatistics> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _lateRecords = [];
  int _monthlyLateCount = 0;
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadLateStatistics();
  }

  Future<void> refresh() => _loadLateStatistics();

  Future<void> _loadLateStatistics() async {
    try {
      setState(() => _isLoading = true);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;

      if (userEmail == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final thisYear = DateTime(now.year, 1, 1);

      // 올해 지각 기록 조회 (날짜/출근시간 포함, 최신순)
      final yearlyData = await _supabase
          .from('attendance_records')
          .select('date, clock_in')
          .eq('user_email', userEmail)
          .eq('status', '지각')
          .gte('date', thisYear.toIso8601String().split('T')[0])
          .order('date', ascending: false);

      final records = List<Map<String, dynamic>>.from(yearlyData as List);
      final monthStartStr = thisMonth.toIso8601String().split('T')[0];
      final monthlyCount = records
          .where((r) => (r['date']?.toString() ?? '').compareTo(monthStartStr) >= 0)
          .length;

      if (!mounted) return;
      setState(() {
        _lateRecords = records;
        _monthlyLateCount = monthlyCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date);
      const days = ['월', '화', '수', '목', '금', '토', '일'];
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$mm.$dd (${days[d.weekday - 1]})';
    } catch (_) {
      return date;
    }
  }

  String _formatTime(String? time) {
    if (time == null) return '-';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // 지각이 없으면 표시하지 않음
    if (_lateRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final yearlyCount = _lateRecords.length;

    // 플랫 토글 섹션 스타일 (아래 지각/미출근 섹션과 동일) — 행 빨간색 표기
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Material(
            color: AppColors.errorLight,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 16),
                  vertical: ResponsiveUtils.spacing(context, 12),
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '나의 지각',
                        style: AppTextStyles.sectionHeader(context).copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    _buildStatItem('이번 달', _monthlyLateCount),
                    SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                    _buildStatItem('올해', yearlyCount),
                    const SizedBox(width: 6),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isExpanded)
            ..._lateRecords.map((r) => FlatTableRow(
                  cells: [
                    Text(_formatDate(r['date']?.toString()),
                        style: AppTextStyles.tableCell(context)),
                    Text(_formatTime(r['clock_in']?.toString()),
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
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.statLabel(context),
        ),
        SizedBox(width: ResponsiveUtils.spacing(context, 4)),
        Text(
          '$count회',
          style: AppTextStyles.sectionHeader(context).copyWith(
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}
