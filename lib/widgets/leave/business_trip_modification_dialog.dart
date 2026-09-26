import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../../services/leave_service.dart';
import '../../providers/leave_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/user_role_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/shared/flat_section.dart';

class BusinessTripModificationDialog extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const BusinessTripModificationDialog({super.key, required this.tripData});

  static Future<void> show(BuildContext context, Map<String, dynamic> tripData) {
    final String endDateStr = tripData['end_date'] ?? '';
    if (endDateStr.isNotEmpty) {
      try {
        final endDate = DateTime.parse(endDateStr);
        final today = DateTime.now();
        final todayMidnight = DateTime(today.year, today.month, today.day);
        if (endDate.isBefore(todayMidnight)) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('안내'),
                ],
              ),
              content: const Text(
                '이미 종료된 출장(과거 일정)은 조기 복귀 또는 일정 연장 신청을 진행할 수 없습니다.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          return Future.value();
        }
      } catch (_) {
      // 실패해도 주 흐름에 영향 없음 (의도적 무시)
    }
    }

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BusinessTripModificationDialog(tripData: tripData),
    );
  }

  @override
  State<BusinessTripModificationDialog> createState() => _BusinessTripModificationDialogState();
}

class _BusinessTripModificationDialogState extends State<BusinessTripModificationDialog> {
  final _client = Supabase.instance.client;
  final _reasonController = TextEditingController();
  DateTime? _selectedEndDate;
  bool _isLoading = false;

  static const double _companyLat = 35.844541;
  static const double _companyLng = 128.506439;
  static const double _allowedDistance = 100.0; // meters

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final roles = UserRoleHelper.getRoles(employee);
    final userId = userProvider.id ?? employee?['id']?.toString() ?? '';
    final userEmail = userProvider.email ?? '';

    // 권한 판단
    final String requesterId = widget.tripData['requester_id']?.toString() ?? '';
    final String requesterEmail = widget.tripData['user_email']?.toString() ?? '';
    final bool isOwner = requesterId == userId || (userEmail.isNotEmpty && requesterEmail == userEmail);

    // 동승자 여부
    bool isCompanion = false;
    final companions = widget.tripData['companions'];
    if (companions is List) {
      isCompanion = companions.any((c) {
        if (c is Map) {
          final cId = c['id']?.toString() ?? '';
          final cName = c['name']?.toString() ?? '';
          return cId == userId || cName == userProvider.name;
        }
        return false;
      });
    }

    final bool isManager = UserRoleHelper.canManageAttendance(roles);
    final bool canModify = isOwner || isCompanion || isManager;

    final String tripCode = widget.tripData['trip_code'] ?? '-';
    final String tripDestination = widget.tripData['place'] ?? '-';
    final String startDateStr = widget.tripData['start_date'] ?? '';
    final String endDateStr = widget.tripData['end_date'] ?? '';
    final String originalEndDateStr = widget.tripData['original_end_date'] ?? endDateStr;
    final String modificationStatus = widget.tripData['modification_status'] ?? '';
    final String requestedEndDateStr = widget.tripData['requested_end_date'] ?? '';

    // 차량/법인카드 표시 텍스트
    final String transportRaw = (widget.tripData['transport'] ?? '').toString();
    final String vehicleName = (widget.tripData['vehicle_name'] ??
            widget.tripData['requested_vehicle_info'] ??
            '')
        .toString();
    String vehicleText = '';
    if (transportRaw == 'company_vehicle') {
      vehicleText = vehicleName.isNotEmpty ? vehicleName : '법인차량';
    } else if (transportRaw == 'personal_vehicle') {
      vehicleText = '개인차량';
    } else if (transportRaw == 'public_transport') {
      vehicleText = '대중교통';
    } else if (vehicleName.isNotEmpty) {
      vehicleText = vehicleName;
    }
    final String cardText =
        (widget.tripData['requested_card_number'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .join(', ') ??
            '';

    // 섹션 박스 (카드 헤더 + 내용)
    Widget section({
      required String title,
      required IconData icon,
      Color? color,
      required List<Widget> children,
    }) {
      return Container(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlatCardHeader(
              title: title,
              icon: icon,
              iconColor: color ?? AppColors.primary,
            ),
            ...children,
          ],
        ),
      );
    }

    Widget padded(Widget child) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: child,
        );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '출장 일정 변경',
                            style: AppTextStyles.appBarTitle(context),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$tripCode · $tripDestination',
                            style: AppTextStyles.listSubtitle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 본문
              Flexible(
                child: Container(
                  color: AppColors.backgroundPrimary,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        section(
                          title: '출장 정보',
                          icon: Icons.info_outline,
                          children: [
                            FlatInfoRow(
                              label: '출장 기간',
                              value: '$startDateStr ~ $endDateStr',
                            ),
                            if (widget.tripData['original_end_date'] != null)
                              FlatInfoRow(label: '최초 종료일', value: originalEndDateStr),
                            if (vehicleText.isNotEmpty)
                              FlatInfoRow(label: '차량', value: vehicleText),
                            if (cardText.isNotEmpty)
                              FlatInfoRow(label: '법인카드', value: cardText),
                            if (modificationStatus == 'extension_pending')
                              FlatInfoRow(
                                label: '연장 대기',
                                value: '$requestedEndDateStr까지',
                                valueColor: AppColors.warning,
                              ),
                          ],
                        ),
                        if (!canModify)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              '본인의 출장 건만 일정을 변경할 수 있습니다.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.listSubtitle(context),
                            ),
                          )
                        else if (modificationStatus == 'extension_pending')
                          section(
                            title: '연장 신청 대기 중',
                            icon: Icons.pending_actions,
                            color: AppColors.warning,
                            children: [
                              padded(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '출장 연장 승인 신청이 대기 중입니다. 취소하려면 아래 버튼을 누르세요.',
                                      style: AppTextStyles.cardBody(context),
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        minimumSize: const Size(0, 40),
                                      ),
                                      onPressed: _isLoading ? null : () => _cancelModification(context),
                                      child: const Text('연장 신청 취소'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          section(
                            title: '조기 복귀 (즉시 완료)',
                            icon: Icons.directions_run,
                            color: AppColors.info,
                            children: [
                              padded(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '지금 시각 기준으로 복귀 완료 처리합니다. 차량 배차는 즉시 복귀완료, 법인카드 사용 종료일은 오늘로 단축됩니다.',
                                      style: AppTextStyles.cardBody(context),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                      ),
                                      onPressed: _isLoading ? null : () => _handleImmediateEarlyReturn(context),
                                      child: const Text('즉시 조기 복귀 완료'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          section(
                            title: '일정 연장 신청 (결재 대기)',
                            icon: Icons.event_repeat,
                            children: [
                              padded(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('연장 종료일', style: AppTextStyles.listSubtitle(context)),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectEndDate(context, endDateStr),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _selectedEndDate == null
                                                ? AppColors.border
                                                : AppColors.primary,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: _selectedEndDate == null
                                                  ? AppColors.textTertiary
                                                  : AppColors.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _selectedEndDate == null
                                                    ? '날짜 선택'
                                                    : DateFormat('yyyy-MM-dd (E)', 'ko_KR')
                                                        .format(_selectedEndDate!),
                                                style: AppTextStyles.tableCell(
                                                  context,
                                                  color: _selectedEndDate == null
                                                      ? AppColors.textDisabled
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 16,
                                              color: AppColors.textTertiary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text('연장 사유', style: AppTextStyles.listSubtitle(context)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: TextField(
                                        controller: _reasonController,
                                        maxLines: 2,
                                        minLines: 2,
                                        style: AppTextStyles.cardBody(context),
                                        decoration: const InputDecoration(
                                          hintText: '연장 사유를 입력하세요',
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                      ),
                                      onPressed: _isLoading ? null : () => _handleRequestExtension(context, endDateStr),
                                      child: const Text('연장 승인 요청'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectEndDate(BuildContext context, String currentEndDateStr) async {
    final currentEndDate = DateTime.parse(currentEndDateStr);
    final initialDate = currentEndDate.add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: currentEndDate.add(const Duration(days: 30)),
    );

    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _cancelModification(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: const Text('신청 취소'),
        content: const Text('출장 일정 변경 신청을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('신청 취소'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final tripId = widget.tripData['business_trip_id'];
      await LeaveService().cancelBusinessTripModification(tripId);

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
        await leaveProvider.fetchMyLeaves(email: userProvider.email!, forceRefresh: true);
        await leaveProvider.fetchAllLeaves(forceRefresh: true);
        if (!context.mounted) return;
        AppBanner.show(context, '변경 신청이 취소되었습니다.', type: BannerType.success);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) AppBanner.show(context, '취소 중 오류: $e', type: BannerType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImmediateEarlyReturn(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: const Text('조기 복귀 처리'),
        content: const Text('지금 시각으로 즉시 조기 복귀 처리하시겠습니까?\n차량 배차가 자동 복귀 처리되며 법인카드의 사용일이 오늘로 단축됩니다.\n(※ 회사 반경 100m 이내에서만 처리가 가능합니다.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복귀 처리'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // 1. 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) AppBanner.show(context, '위치 서비스를 켜주세요.', type: BannerType.error);
        setState(() => _isLoading = false);
        return;
      }

      // 2. 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) AppBanner.show(context, '위치 권한이 필요합니다.', type: BannerType.error);
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) AppBanner.show(context, '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.', type: BannerType.error);
        setState(() => _isLoading = false);
        return;
      }

      // 3. 현재 위치 정보 가져오기
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        // 단말 기종이나 OS에 따라 재시도
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (_) {
      // 실패해도 주 흐름에 영향 없음 (의도적 무시)
    }
      }

      if (pos == null) {
        if (mounted) AppBanner.show(context, '위치 정보를 가져오는데 실패했습니다. GPS 신호 상태를 확인해주세요.', type: BannerType.error);
        setState(() => _isLoading = false);
        return;
      }

      // 4. 회사 반경 100m 검증 (디버그 모드가 아닐 때 적용)
      if (!kDebugMode) {
        final distance = _calculateDistance(
          pos.latitude,
          pos.longitude,
          _companyLat,
          _companyLng,
        );
        if (distance > _allowedDistance) {
          if (mounted) {
            AppBanner.show(
              context,
              '회사 내부(반경 100m 이내)에서만 조기 복귀 처리가 가능합니다.\n(현재 거리: ${distance.toStringAsFixed(1)}m)',
              type: BannerType.error,
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final tripId = widget.tripData['business_trip_id'];

      // 차량 배차 및 법인카드 ID 조회
      dynamic linkedVehicleId;
      List<dynamic> linkedCardIds = [];

      try {
        final vehicleRes = await _client
            .from('vehicle_requests')
            .select('id')
            .eq('business_trip_id', tripId)
            .not('approval_status', 'eq', 'rejected')
            .maybeSingle();
        linkedVehicleId = vehicleRes?['id'];

        final cardsRes = await _client
            .from('card_usages')
            .select('id')
            .eq('business_trip_id', tripId);
        linkedCardIds = cardsRes.map((c) => c['id']).toList();
            } catch (_) {
      // 실패해도 주 흐름에 영향 없음 (의도적 무시)
    }

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final department = widget.tripData['request_department'] ?? widget.tripData['employees']?['department'] ?? '개발팀';

      await LeaveService().immediateEarlyReturn(
        businessTripId: tripId,
        originalEndDate: widget.tripData['end_date'],
        requesterName: widget.tripData['name'] ?? userProvider.name ?? '임직원',
        tripCode: widget.tripData['trip_code'] ?? '',
        requestDepartment: department,
        currentUserId: userProvider.id ?? userProvider.employee?['id']?.toString(),
        linkedVehicleId: linkedVehicleId,
        linkedCardIds: linkedCardIds,
      );

      if (mounted) {
        final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
        await leaveProvider.fetchMyLeaves(email: userProvider.email!, forceRefresh: true);
        await leaveProvider.fetchAllLeaves(forceRefresh: true);
        if (!mounted) return;
        AppBanner.show(context, '조기 복귀 처리가 완료되었습니다.', type: BannerType.success);
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppBanner.show(context, '처리 중 오류: $e', type: BannerType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRequestExtension(BuildContext context, String currentEndDateStr) async {
    if (_selectedEndDate == null) {
      AppBanner.show(context, '연장 종료일을 선택해주세요.', type: BannerType.error);
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppBanner.show(context, '연장 사유를 입력해주세요.', type: BannerType.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final tripId = widget.tripData['business_trip_id'];
      final requestedEndDate = DateFormat('yyyy-MM-dd').format(_selectedEndDate!);

      // 차량/법인카드 예약 중복 체크
      bool hasConflict = false;
      String conflictDetails = '';

      // 차량 체크
      final vInfo = widget.tripData['requested_vehicle_info'] ?? widget.tripData['vehicle_name'];
      if (vInfo != null && vInfo.toString().isNotEmpty && widget.tripData['transport'] == 'company_vehicle') {
        final vString = vInfo.toString();
        final vehiclePlate = vString.split(' ').last;
        final vehicleLabel = vString.split(' ').first;

        final scheds = await _client
            .from('vehicle_requests')
            .select('*')
            .inFilter('approval_status', ['approved', 'pending'])
            .neq('business_trip_id', tripId);

        for (final sched in scheds) {
          final schedInfo = sched['vehicle_info']?.toString() ?? '';
          if (schedInfo.contains(vehiclePlate) || schedInfo.contains(vehicleLabel)) {
            final sStart = DateTime.parse(sched['start_at']);
            final sEnd = DateTime.parse(sched['end_at']);
            final rangeStart = DateTime.parse(currentEndDateStr).add(const Duration(days: 1));
            final rangeEnd = _selectedEndDate!;

            if (sStart.isBefore(rangeEnd.add(const Duration(seconds: 1))) &&
                sEnd.isAfter(rangeStart.subtract(const Duration(seconds: 1)))) {
              hasConflict = true;
              conflictDetails += '🚗 차량 [$vString]이 해당 기간에 중복 예약되어 있습니다.\n';
              break;
            }
          }
        }
            }

      // 카드 체크
      final cardInfo = widget.tripData['requested_card_number'] ?? widget.tripData['card_number'];
      if (cardInfo != null) {
        final cardsList = cardInfo is List ? cardInfo : [cardInfo.toString()];
        final otherTrips = await _client
            .from('business_trips')
            .select('*')
            .neq('id', tripId)
            .not('approval_status', 'eq', 'rejected');

        for (final other in otherTrips) {
          final otherCards = other['requested_card_number'];
          if (otherCards is List) {
            final hasSharedCard = cardsList.any((c) => otherCards.contains(c));
            if (hasSharedCard) {
              final oStart = DateTime.parse(other['trip_start_date']);
              final oEnd = DateTime.parse(other['trip_end_date']);
              final rangeStart = DateTime.parse(currentEndDateStr).add(const Duration(days: 1));
              final rangeEnd = _selectedEndDate!;

              if (oStart.isBefore(rangeEnd.add(const Duration(seconds: 1))) &&
                  oEnd.isAfter(rangeStart.subtract(const Duration(seconds: 1)))) {
                hasConflict = true;
                conflictDetails += '💳 법인카드가 해당 기간에 다른 출장에 사용 중입니다.\n';
                break;
              }
            }
          }
        }
            }

      if (hasConflict) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            title: const Text('중복 예약 경고'),
            content: Text('$conflictDetails\n그래도 연장 신청을 진행하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                child: const Text('진행'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final department = widget.tripData['request_department'] ?? widget.tripData['employees']?['department'] ?? '개발팀';

      await LeaveService().requestBusinessTripModification(
        businessTripId: tripId,
        requestedEndDate: requestedEndDate,
        reason: reason,
        originalEndDate: currentEndDateStr,
        requesterName: widget.tripData['name'] ?? userProvider.name ?? '임직원',
        tripCode: widget.tripData['trip_code'] ?? '',
        requestDepartment: department,
      );

      if (mounted) {
        final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
        await leaveProvider.fetchMyLeaves(email: userProvider.email!, forceRefresh: true);
        await leaveProvider.fetchAllLeaves(forceRefresh: true);
        if (!mounted) return;
        AppBanner.show(context, '연장 승인 요청이 접수되었습니다.', type: BannerType.success);
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppBanner.show(context, '요청 중 오류: $e', type: BannerType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
