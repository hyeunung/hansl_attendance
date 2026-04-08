import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

/// 금일 차량 현황 위젯
class TodayVehicleWidget extends StatefulWidget {
  final Function(bool isNonWorkingDay)? onWorkingDayStatusChanged;

  const TodayVehicleWidget({super.key, this.onWorkingDayStatusChanged});

  @override
  State<TodayVehicleWidget> createState() => _TodayVehicleWidgetState();
}

class _TodayVehicleWidgetState extends State<TodayVehicleWidget> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicleRequests = [];
  bool _isNonWorkingDay = false;
  String? _holidayName;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 주말 체크
      final isWeekend = today.weekday >= 6;

      // 공휴일 체크
      final holiday = await _supabase
          .from('holidays')
          .select('name')
          .eq('date', todayStr)
          .maybeSingle();
      final isHoliday = holiday != null;

      if (isWeekend || isHoliday) {
        String dayType;
        if (isWeekend && isHoliday) {
          dayType = holiday['name'] as String;
        } else if (isWeekend) {
          dayType = today.weekday == 6 ? '토요일' : '일요일';
        } else if (isHoliday) {
          dayType = holiday['name'] as String;
        } else {
          dayType = '휴일';
        }

        if (!mounted) return;
        setState(() {
          _isNonWorkingDay = true;
          _holidayName = dayType;
          _isLoading = false;
        });
        widget.onWorkingDayStatusChanged?.call(true);
        return;
      }

      widget.onWorkingDayStatusChanged?.call(false);

      // 오늘 날짜에 걸치는 승인된 차량 배차 조회
      // start_at <= 오늘 끝 AND end_at >= 오늘 시작
      final todayStart = '${todayStr}T00:00:00+09:00';
      final todayEnd = '${todayStr}T23:59:59+09:00';

      final data = await _supabase
          .from('vehicle_requests')
          .select('id, vehicle_info, route, start_at, end_at')
          .eq('approval_status', 'approved')
          .lte('start_at', todayEnd)
          .gte('end_at', todayStart)
          .order('start_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _vehicleRequests = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatPeriod(String? startAt, String? endAt) {
    if (startAt == null || endAt == null) return '-';
    try {
      final start = DateTime.parse(startAt).toLocal();
      final end = DateTime.parse(endAt).toLocal();

      final startDate = '${start.month}/${start.day}';
      final endDate = '${end.month}/${end.day}';

      if (startDate == endDate) {
        return startDate;
      }
      return '$startDate~$endDate';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isNonWorkingDay) {
      return _buildNonWorkingDayWidget();
    }

    final count = _vehicleRequests.length;

    return Container(
      color: Colors.white,
      child: FlatToggleSection(
        title: '금일 차량 현황 ($count)',
        icon: Icons.directions_car_outlined,
        isExpanded: _isExpanded,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        children: [
          if (_vehicleRequests.isEmpty)
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
              child: Text(
                '오늘 배차된 차량이 없습니다',
                style: AppTextStyles.statLabel(context),
              ),
            )
          else ...[
            // 컬럼 헤더
            FlatTableColumnHeader(
              columns: const [
                FlatColumn(label: '차량', flex: 3),
                FlatColumn(label: '지역/출장지', flex: 3),
                FlatColumn(label: '기간', flex: 3, align: TextAlign.end),
              ],
            ),
            // 데이터 행
            ..._vehicleRequests.map((v) {
              final vehicleInfo = v['vehicle_info'] as String? ?? '-';
              final vehicleName = vehicleInfo.split(' ').first;
              final route = v['route'] as String? ?? '-';
              final period = _formatPeriod(
                v['start_at'] as String?,
                v['end_at'] as String?,
              );

              return FlatTableRow(
                cells: [
                  Text(vehicleName,
                      style: AppTextStyles.tableCell(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis),
                  Text(route,
                      style: AppTextStyles.tableCellSub(context),
                      overflow: TextOverflow.ellipsis),
                  Text(period,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.tableCellSub(context)),
                ],
                flexValues: const [3, 3, 3],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildNonWorkingDayWidget() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const FlatSectionHeader(title: '금일 차량 현황'),
          Padding(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
            child: Column(
              children: [
                Icon(
                  Icons.weekend_outlined,
                  size: 32,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                Text(
                  _holidayName ?? '휴일',
                  style: AppTextStyles.sectionHeader(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
