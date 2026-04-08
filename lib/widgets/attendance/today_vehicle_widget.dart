import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/user_role_helper.dart';
import '../../providers/user_provider.dart';
import '../shared/flat_section.dart';

/// 금일 차량 현황 위젯
class TodayVehicleWidget extends StatefulWidget {
  final Function(bool isNonWorkingDay)? onWorkingDayStatusChanged;

  const TodayVehicleWidget({super.key, this.onWorkingDayStatusChanged});

  @override
  State<TodayVehicleWidget> createState() => TodayVehicleWidgetState();
}

class TodayVehicleWidgetState extends State<TodayVehicleWidget> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicleRequests = [];
  bool _isNonWorkingDay = false;
  String? _holidayName;
  bool _isExpanded = false;

  // 복귀 관련
  Map<String, dynamic>? _myActiveRequest; // 본인 차량
  List<Map<String, dynamic>> _othersActiveRequests = []; // 타인 차량 (관리자용)
  bool _isAdmin = false;
  bool _returnExpanded = false;
  int? _returningId; // 현재 복귀 처리 중인 요청 ID

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

      final todayStart = '${todayStr}T00:00:00+09:00';
      final todayEnd = '${todayStr}T23:59:59+09:00';

      // 오늘 승인된 차량 배차 조회
      final data = await _supabase
          .from('vehicle_requests')
          .select('id, vehicle_info, route, start_at, end_at, requester_id')
          .eq('approval_status', 'approved')
          .lte('start_at', todayEnd)
          .gte('end_at', todayStart)
          .order('start_at', ascending: true);

      final vehicles = List<Map<String, dynamic>>.from(data);

      // 현재 사용자 정보
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.id;
      final roles = UserRoleHelper.getRoles(userProvider.employee);
      final isAdmin = UserRoleHelper.isAppAdmin(roles) ||
          roles.contains('hr');

      // 본인 / 타인 분리
      Map<String, dynamic>? myRequest;
      final othersRequests = <Map<String, dynamic>>[];

      if (userId != null) {
        // 요청자 이름 매핑을 위해 requester_id 수집
        final requesterIds = vehicles
            .map((v) => v['requester_id'] as String?)
            .where((id) => id != null && id != userId)
            .toSet()
            .toList();

        // 타인 이름 조회
        Map<String, String> nameMap = {};
        if (isAdmin && requesterIds.isNotEmpty) {
          final empData = await _supabase
              .from('employees')
              .select('id, name')
              .inFilter('id', requesterIds);
          for (final emp in empData) {
            nameMap[emp['id'] as String] = emp['name'] as String? ?? '-';
          }
        }

        for (final v in vehicles) {
          if (v['requester_id'] == userId) {
            myRequest = v;
          } else if (isAdmin) {
            v['requester_name'] = nameMap[v['requester_id']] ?? '-';
            othersRequests.add(v);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _vehicleRequests = vehicles;
        _myActiveRequest = myRequest;
        _othersActiveRequests = othersRequests;
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReturn(int requestId) async {
    if (_returningId != null) return;

    setState(() => _returningId = requestId);
    try {
      await _supabase
          .from('vehicle_requests')
          .update({'approval_status': 'returned'})
          .eq('id', requestId);

      if (!mounted) return;
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('차량 복귀 처리되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('복귀 처리에 실패했습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _returningId = null);
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
      child: Column(
        children: [
          // 금일 차량 현황 (드롭다운)
          FlatToggleSection(
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
                FlatTableColumnHeader(
                  columns: const [
                    FlatColumn(label: '차량', flex: 3),
                    FlatColumn(label: '지역/출장지', flex: 3),
                    FlatColumn(label: '기간', flex: 3, align: TextAlign.end),
                  ],
                ),
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

          // 본인 차량 복귀 버튼 (바로 노출)
          if (_myActiveRequest != null)
            _buildReturnButton(
              _myActiveRequest!,
              showName: false,
            ),

          // 관리자: 타인 차량 복귀 (드롭다운)
          if (_isAdmin && _othersActiveRequests.isNotEmpty)
            FlatToggleSection(
              title: '차량 복귀 관리 (${_othersActiveRequests.length})',
              icon: Icons.assignment_return_outlined,
              color: AppColors.primary,
              isExpanded: _returnExpanded,
              onTap: () => setState(() => _returnExpanded = !_returnExpanded),
              children: [
                ..._othersActiveRequests.map((v) => _buildReturnButton(
                      v,
                      showName: true,
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReturnButton(
    Map<String, dynamic> request, {
    required bool showName,
  }) {
    final vehicleInfo = request['vehicle_info'] as String? ?? '-';
    final vehicleName = vehicleInfo.split(' ').first;
    final route = request['route'] as String? ?? '';
    final requestId = request['id'] as int;
    final isProcessing = _returningId == requestId;
    final requesterName = request['requester_name'] as String?;

    final label = showName && requesterName != null
        ? '$requesterName - $vehicleName${route.isNotEmpty ? ' ($route)' : ''}'
        : '$vehicleName 차량 복귀${route.isNotEmpty ? ' ($route)' : ''}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 6),
      ),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [AppShadows.button],
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 8),
          ),
        ),
        child: ElevatedButton.icon(
          onPressed: isProcessing ? null : () => _handleReturn(requestId),
          icon: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.assignment_return, size: 18),
          label: Text(
            label,
            style: AppTextStyles.buttonPrimary(context),
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.spacing(context, 14),
              horizontal: ResponsiveUtils.spacing(context, 12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 8),
              ),
            ),
          ),
        ),
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
