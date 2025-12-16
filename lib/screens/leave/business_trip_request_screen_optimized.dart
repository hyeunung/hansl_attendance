import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/validators/leave_validators.dart';
import '../../widgets/business_trip/trip_calendar_widget.dart';
import '../../widgets/business_trip/trip_date_chips_widget.dart';
import '../../widgets/business_trip/transport_selector_widget.dart';
import '../../widgets/business_trip/employee_selector_widget.dart';
import '../../widgets/business_trip/trip_info_input_widget.dart';
import '../../widgets/business_trip/trip_info_card_widget.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../main_tab.dart';

/// 최적화된 출장 신청 화면
/// 컴포넌트 분리, 성능 최적화, 보안 강화 적용
class BusinessTripRequestScreenOptimized extends StatefulWidget {
  const BusinessTripRequestScreenOptimized({super.key});

  @override
  State<BusinessTripRequestScreenOptimized> createState() =>
      _BusinessTripRequestScreenOptimizedState();
}

class _BusinessTripRequestScreenOptimizedState
    extends State<BusinessTripRequestScreenOptimized>
    with AutomaticKeepAliveClientMixin, BannerControllerMixin {
  // Controllers
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final FocusNode _placeFocusNode = FocusNode();
  final FocusNode _purposeFocusNode = FocusNode();

  // State variables
  String? _selectedTransport;
  final Set<DateTime> _selectedDates = {};
  String? _selectedEmployee;
  List<String> _employeeList = [];
  List<String> _selectedCompanions = [];
  bool _isLoadingEmployees = false;
  bool _isSubmitting = false;
  DateTime _focusedDay = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _placeController.dispose();
    _purposeController.dispose();
    _placeFocusNode.dispose();
    _purposeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoadingEmployees = true);

    try {
      final service = SupabaseService();
      final response = await service.fetchEmployees();
      if (!context.mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      String? myName = userProvider.name;

      setState(() {
        _employeeList = response;
        _isLoadingEmployees = false;

        // 내 이름 자동 선택
        if (_employeeList.isNotEmpty) {
          if (myName != null && _employeeList.contains(myName)) {
            _selectedEmployee = myName;
          } else {
            _selectedEmployee = _employeeList.first;
          }
        }
      });

      // Debug code removed
    } catch (e) {
      // Debug code removed
      showBanner('직원 목록을 불러오는데 실패했습니다', type: BannerType.error);
    }
  }

  void _handleDaySelected(DateTime selectedDay) {
    setState(() {
      if (_selectedDates.contains(selectedDay)) {
        _selectedDates.remove(selectedDay);
      } else {
        _selectedDates.add(selectedDay);
      }
    });
  }

  void _handleDateRemove(DateTime date) {
    setState(() {
      _selectedDates.remove(date);
    });
  }

  Future<void> _submitRequest() async {
    // Debug print removed

    // 유효성 검사
    if (!_validateInputs()) {
      // Debug print removed
      return;
    }

    // Debug print removed
    setState(() => _isSubmitting = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);

      // 날짜 정렬
      final sortedDates = _selectedDates.toList()..sort();

      // 연속된 날짜 그룹화
      final List<List<DateTime>> dateGroups = [];
      List<DateTime> currentGroup = [];

      for (final date in sortedDates) {
        if (currentGroup.isEmpty) {
          currentGroup.add(date);
        } else {
          final lastDate = currentGroup.last;
          final difference = date.difference(lastDate).inDays;
          if (difference == 1) {
            // 연속된 날짜면 같은 그룹에 추가
            currentGroup.add(date);
          } else {
            // 연속되지 않으면 새 그룹 시작
            dateGroups.add(currentGroup);
            currentGroup = [date];
          }
        }
      }
      if (currentGroup.isNotEmpty) {
        dateGroups.add(currentGroup);
      }

      // 각 그룹에 대해 하나의 신청으로 처리 (병렬 처리로 성능 개선)
      List<Future<void>> requestFutures = [];

      for (final group in dateGroups) {
        final startDate = group.first;
        final endDate = group.last;

        // 신규 구조: reason에 정보를 합치지 않고 컬럼으로만 저장
        final travelers = <String>[
          _selectedEmployee!,
          ..._selectedCompanions,
        ];

        requestFutures.add(
          leaveProvider.requestBiztrip(
            userEmail: userProvider.email!,
            startDate: startDate,
            endDate: endDate,
            travelers: travelers,
            place: LeaveValidators.sanitizeInput(_placeController.text),
            // 업무내용(reason)은 줄바꿈을 유지해야 함
            reason: LeaveValidators.sanitizeMultilineInput(_purposeController.text),
            transport: _selectedTransport!,
          ),
        );
      }

      // 모든 요청을 병렬로 처리
      await Future.wait(requestFutures);

      // 성공 메시지
      final totalDays = sortedDates.length;
      final groupCount = dateGroups.length;
      final message = groupCount > 1
          ? '출장 신청이 완료되었습니다 ($totalDays일, $groupCount건)'
          : '출장 신청이 완료되었습니다 ($totalDays일)';

      showBanner(
        message,
        type: BannerType.success,
        duration: const Duration(seconds: 3),
      );

      // 데이터는 이미 requestLeave에서 자동으로 새로고침됨 (fetchAllLeaves 포함)

      // 화면 초기화
      _resetForm();

      // 메인 화면으로 이동
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainTab(initialIndex: 1)),
          (route) => false,
        );
      }
    } catch (e) {
      // Debug code removed
      showBanner('출장 신청에 실패했습니다. 다시 시도해주세요.', type: BannerType.error);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  bool _validateInputs() {
    if (_selectedDates.isEmpty) {
      showBanner('출장 날짜를 선택해주세요', type: BannerType.warning);
      return false;
    }

    if (_placeController.text.trim().isEmpty) {
      showBanner('출장 장소를 입력해주세요', type: BannerType.warning);
      _placeFocusNode.requestFocus();
      return false;
    }

    if (_purposeController.text.isEmpty) {
      showBanner('출장 목적을 입력해주세요', type: BannerType.warning);
      _purposeFocusNode.requestFocus();
      return false;
    }

    if (_selectedTransport == null) {
      showBanner('교통수단을 선택해주세요', type: BannerType.warning);
      return false;
    }

    // 입력값 검증
    final placeError = LeaveValidators.validatePlace(_placeController.text);
    if (placeError != null) {
      showBanner(placeError, type: BannerType.error);
      return false;
    }

    final purposeError = LeaveValidators.validatePurpose(
      _purposeController.text,
    );
    if (purposeError != null) {
      showBanner(purposeError, type: BannerType.error);
      return false;
    }

    return true;
  }

  void _resetForm() {
    setState(() {
      _selectedDates.clear();
      _placeController.clear();
      _purposeController.clear();
      _selectedTransport = null;
      _selectedCompanions.clear();
      _focusedDay = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildBanner(),
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildCalendarSection(),
                    const SizedBox(height: 16),
                    _buildSelectedDatesSection(),
                    const SizedBox(height: 16),
                    _buildInputSection(),
                    const SizedBox(height: 16),
                    _buildTransportSection(),
                    const SizedBox(height: 16),
                    _buildEmployeeSection(),
                    const SizedBox(height: 24), // 하단 여백 줄임
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        '출장 신청',
        style: ResponsiveUtils.getTextStyle(
          context,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white, // 흰색으로 변경
        ),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildInfoCard() {
    // 기본 통계 카드로 대체: 이번 달/올해 출장 횟수 (간단 계산)
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    // 현재 선택된 날짜 중 이번 달과 올해 카운트(간단 지표)
    final monthTrips = _selectedDates
        .where((d) => d.year == year && d.month == month)
        .length;
    final yearTrips = _selectedDates.where((d) => d.year == year).length;

    return TripInfoCardWidget(
      monthTrips: monthTrips,
      yearTrips: yearTrips,
      currentMonth: month,
      currentYear: year,
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '출장 날짜 선택',
          style: ResponsiveUtils.getTextStyle(context, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TripCalendarWidget(
          selectedDates: _selectedDates,
          onDaySelected: _handleDaySelected,
          focusedDay: _focusedDay,
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
        ),
      ],
    );
  }

  Widget _buildSelectedDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '선택된 날짜',
          style: ResponsiveUtils.getTextStyle(context, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TripDateChipsWidget(
          selectedDates: _selectedDates,
          onRemove: _handleDateRemove,
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return TripInfoInputWidget(
      placeController: _placeController,
      purposeController: _purposeController,
      placeFocusNode: _placeFocusNode,
      purposeFocusNode: _purposeFocusNode,
      selectedDates: _selectedDates,
      onRemoveDate: (d) => _handleDateRemove(d),
      onSelectDates: () {}, // 날짜 선택은 상단 캘린더 섹션에서 처리
      onPlaceChanged: (_) => setState(() {}),
      onPurposeChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTransportSection() {
    return TransportSelectorWidget(
      selectedTransport: _selectedTransport,
      transportOptions: const [
        '펠리세이드',
        '스타리아',
        'GV80',
        'GV90',
        '자차',
        'KTX(SRT)',
        '버스',
        '비행기',
      ],
      onChanged: (value) {
        setState(() => _selectedTransport = value);
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (MediaQuery.of(context).viewInsets.bottom > 0)
              const SizedBox(width: 48),
            Expanded(child: _buildSubmitButton()),
            const SizedBox(width: 8),
            if (MediaQuery.of(context).viewInsets.bottom > 0)
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () => FocusScope.of(context).unfocus(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSection() {
    return EmployeeSelectorWidget(
      selectedEmployee: _selectedEmployee,
      selectedCompanions: _selectedCompanions,
      employeeList: _employeeList,
      isLoading: _isLoadingEmployees,
      onSelectEmployee: () async {
        final result = await showDialog(
          context: context,
          builder: (_) => EmployeeSelectionDialog(
            employeeList: _employeeList,
            currentSelection: _selectedEmployee,
            title: '출장자 선택',
          ),
        );
        if (result is String) {
          setState(() => _selectedEmployee = result);
        }
      },
      onSelectCompanions: () async {
        final result = await showDialog<List<String>>(
          context: context,
          builder: (_) => EmployeeSelectionDialog(
            employeeList: _employeeList
                .where((n) => n != _selectedEmployee)
                .toList(),
            isMultiSelect: true,
            selectedEmployees: _selectedCompanions,
            title: '추가 인원 선택',
          ),
        );
        if (result != null) {
          setState(() => _selectedCompanions = result);
        }
      },
      onRemoveCompanion: (name) {
        setState(() => _selectedCompanions.remove(name));
      },
    );
  }

  Widget _buildSubmitButton() {
    final isValid =
        _selectedDates.isNotEmpty &&
        _placeController.text.isNotEmpty &&
        _purposeController.text.isNotEmpty && // 공백만 있어도 허용
        _selectedTransport != null &&
        _selectedEmployee != null;

    return GestureDetector(
      onTap: isValid && !_isSubmitting ? _submitRequest : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: isValid ? AppColors.primaryGradient : null,
          color: isValid ? null : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isValid
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                '출장 신청하기',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.white : const Color(0xFFB0B0B0),
                ),
              ),
      ),
    );
  }
}
