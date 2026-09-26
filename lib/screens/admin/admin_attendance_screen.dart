import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/admin_attendance_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/shared/flat_section.dart';
import 'admin_attendance_edit_sheet.dart';

/// 전체 직원 근태 관리 화면 (hr/SuperAdmin 전용)
///
/// 웹앱 hanslworkspace의 AttendanceList.tsx를 Flutter로 이식.
/// 날짜별 전 직원 근태 조회 + 수정 기능 제공.
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final AdminAttendanceService _service = AdminAttendanceService();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _statusFilter = '전체';
  String _searchQuery = '';
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];
  RealtimeChannel? _channel;

  static const List<String> _statusOptions = [
    '전체',
    '정상 출근',
    '지각',
    '퇴근',
    '오전반차',
    '오후반차',
    '연차',
    '출장',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _loadData();
    _setupRealtime();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    _channel = Supabase.instance.client
        .channel('admin_attendance_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_records',
          callback: (_) => _loadData(silent: true),
        )
        .subscribe();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _service.fetchAttendanceByDate(_selectedDate);
      if (mounted) {
        setState(() {
          _records = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppBanner.show(context, '데이터 로드 실패: $e', type: BannerType.error);
      }
    }
  }

  void _moveDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ko'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _goToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDate = DateTime(today.year, today.month, today.day);
    });
    _loadData();
  }

  List<Map<String, dynamic>> get _filtered {
    return _records.where((r) {
      // 상태 필터
      if (_statusFilter != '전체') {
        if (r['status'] != _statusFilter) return false;
      }
      // 검색 필터
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (r['employee_name'] ?? '').toString().toLowerCase();
        final email = (r['email'] ?? '').toString().toLowerCase();
        final dept = (r['department'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !dept.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openEditSheet(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminAttendanceEditSheet(
        record: record,
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
          AppBanner.show(context, '근태 정보가 업데이트되었습니다',
              type: BannerType.success);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '전체 근태 관리',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          _buildDateNav(),
          _buildSummaryCard(),
          _buildFilterChips(),
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildDateNav() {
    final weekday = ['일', '월', '화', '수', '목', '금', '토'][_selectedDate.weekday % 7];
    return Container(
      margin: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.spacing(context, 12),
        horizontal: ResponsiveUtils.spacing(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: AppColors.textSecondary,
            onPressed: () => _moveDate(-1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Center(
                child: Text(
                  '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')} ($weekday)',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: AppColors.textSecondary,
            onPressed: () => _moveDate(1),
          ),
          TextButton(
            onPressed: _goToday,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('오늘'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _records.length;
    final clockedIn = _records.where((r) => r['clock_in'] != null).length;
    final late = _records.where((r) => r['status'] == '지각').length;
    final onLeave = _records
        .where((r) => r['has_leave'] == true || r['has_biztrip'] == true)
        .length;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
      ),
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 14)),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('전체', '$total명'),
          _summaryItem('출근', '$clockedIn'),
          _summaryItem('지각', '$late'),
          _summaryItem('연차/출장', '$onLeave'),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveUtils.spacing(context, 16),
        ResponsiveUtils.spacing(context, 14),
        ResponsiveUtils.spacing(context, 16),
        0,
      ),
      // 가로 스크롤 시 마지막 칩이 화면 밖으로 잘려 보여 줄바꿈 방식으로 변경
      child: Wrap(
        spacing: ResponsiveUtils.spacing(context, 8),
        runSpacing: ResponsiveUtils.spacing(context, 8),
        children: _statusOptions.map((option) {
          final selected = _statusFilter == option;
          return ChoiceChip(
            label: Text(option),
            selected: selected,
            onSelected: (_) => setState(() => _statusFilter = option),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '직원명 또는 이메일로 검색',
          hintStyle: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              '조건에 맞는 직원이 없습니다',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          ResponsiveUtils.spacing(context, 16),
          0,
          ResponsiveUtils.spacing(context, 16),
          ResponsiveUtils.spacing(context, 24),
        ),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _buildRecordCard(filtered[i]),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> r) {
    final name = r['employee_name'] ?? '-';
    final dept = r['department'] ?? '-';
    final status = r['status'] ?? '-';
    final clockIn = r['clock_in'] as String?;
    final clockOut = r['clock_out'] as String?;
    final statusColor = _statusColor(status);

    // 한 행 구성: 상태선 | 이름 | 부서 | 출퇴근 시각 | 상태 | 화살표
    return Material(
      color: AppColors.backgroundCard,
      child: InkWell(
        onTap: () => _openEditSheet(r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.spacing(context, 14),
            vertical: ResponsiveUtils.spacing(context, 8),
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: ResponsiveUtils.spacing(context, 22),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 10)),
              SizedBox(
                width: ResponsiveUtils.spacing(context, 52),
                child: Text(
                  name,
                  style: AppTextStyles.tableCell(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.spacing(context, 62),
                child: Text(
                  dept,
                  style: AppTextStyles.listSubtitle(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  _buildTimeText(clockIn, clockOut),
                  style: AppTextStyles.tableCellSub(context),
                ),
              ),
              StatusChip(label: status, color: statusColor, fontSize: 10),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildTimeText(String? clockIn, String? clockOut) {
    String fmt(String? t) {
      if (t == null || t.isEmpty) return '--:--';
      // clock_in/out은 time 타입 (HH:MM:SS 또는 HH:MM)
      return t.length >= 5 ? t.substring(0, 5) : t;
    }

    return '${fmt(clockIn)}  →  ${fmt(clockOut)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case '정상 출근':
      case '연차':
        return AppColors.success;
      case '지각':
        return const Color(0xFFFF3B30);
      case '오전반차':
      case '오후반차':
        return AppColors.warning;
      case '출장':
        return const Color(0xFF1976D2);
      case '공가':
        return AppColors.gray500;
      case '퇴근':
        return AppColors.gray600;
      default:
        return AppColors.textTertiary;
    }
  }
}
