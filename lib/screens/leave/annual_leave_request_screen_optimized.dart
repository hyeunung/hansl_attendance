import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/leave_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/leave_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/leave/leave_calendar_widget.dart';
import '../../widgets/leave/leave_type_selector_widget.dart';
import '../../widgets/leave/leave_info_card_widget.dart';
import '../../widgets/leave/leave_memo_input_widget.dart';
import '../../widgets/leave/leave_date_chips_widget.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../utils/validators/leave_validators.dart';


/// 성능 최적화된 연차 신청 화면
/// - 불필요한 rebuild 방지
/// - 선택적 Consumer 사용
/// - 메모이제이션 적용
class AnnualLeaveRequestScreenOptimized extends StatefulWidget {
  const AnnualLeaveRequestScreenOptimized({super.key});

  @override
  State<AnnualLeaveRequestScreenOptimized> createState() =>
      _AnnualLeaveRequestScreenOptimizedState();
}

class _AnnualLeaveRequestScreenOptimizedState
    extends State<AnnualLeaveRequestScreenOptimized>
    with BannerControllerMixin, AutomaticKeepAliveClientMixin {
  // Controllers
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _memoFocusNode = FocusNode();

  // State
  LeaveType? _selectedType;
  final Map<LeaveType, Set<DateTime>> _selectedDatesMap = {
    LeaveType.annual: {},
    LeaveType.halfAm: {},
    LeaveType.halfPm: {},
    LeaveType.official: {},
    LeaveType.adjust: {},
  };

  // 성능 최적화를 위한 캐시
  Set<DateTime>? _cachedDisabledDates;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  bool get wantKeepAlive => true; // 화면 상태 유지

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  @override
  void dispose() {
    _memoController.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  /// 연차 정보 로드 (한 번만 실행)
  Future<void> _loadLeaveData() async {
    if (_isLoading) return; // 중복 로드 방지

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final leaveProvider = context.read<LeaveProvider>();

      if (userProvider.email != null) {
        final stopwatch = Stopwatch()..start();

        await leaveProvider.fetchMyLeaves(
          email: userProvider.email!,
          forceRefresh: true,
        );

        stopwatch.stop();
        // Debug code removed

        // 캐시 업데이트
        _updateDisabledDatesCache(leaveProvider.myLeaves);
      }
    } catch (e) {
      // Debug code removed
      showBanner(
        '연차 정보를 불러오는데 실패했습니다.',
        type: BannerType.error,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // myLeaves 캐시 (반차 체크용)
  List<Map<String, dynamic>> _cachedMyLeaves = [];

  /// 비활성화된 날짜 캐시 업데이트 (반려된 연차는 제외)
  void _updateDisabledDatesCache(List<Map<String, dynamic>> myLeaves) {
    _cachedMyLeaves = myLeaves;
    // 연차/공가만 완전 비활성화 (반차는 같은 날에 다른 반차 신청 가능)
    _cachedDisabledDates = myLeaves
        .where((l) => l['status'] != 'rejected')
        .where((l) => l['type'] == 'annual' || l['type'] == 'official')
        .map((l) {
          final start = DateTime.parse(l['start_date']);
          final end = DateTime.parse(l['end_date']);
          return List.generate(
            end.difference(start).inDays + 1,
            (i) => DateTime(start.year, start.month, start.day + i),
          );
        })
        .expand((x) => x)
        .toSet();
  }

  /// 해당 날짜에 신청된 연차 유형들을 반환
  Set<String> _getLeaveTypesForDate(DateTime day) {
    final types = <String>{};
    for (final leave in _cachedMyLeaves) {
      if (leave['status'] == 'rejected') continue;
      final start = DateTime.parse(leave['start_date']);
      final end = DateTime.parse(leave['end_date']);
      final dates = List.generate(
        end.difference(start).inDays + 1,
        (i) => DateTime(start.year, start.month, start.day + i),
      );
      if (dates.any((d) => isSameDay(d, day))) {
        types.add(leave['type'] ?? '');
      }
    }
    return types;
  }

  /// 해당 날짜가 현재 선택된 유형으로 신청 가능한지 확인
  bool _canSelectDateForType(DateTime day) {
    final existingTypes = _getLeaveTypesForDate(day);
    
    // 아무것도 신청되지 않았으면 선택 가능
    if (existingTypes.isEmpty) return true;
    
    // 연차(annual) 또는 공가(official)가 있으면 해당 날짜 사용 불가
    if (existingTypes.contains('annual') || existingTypes.contains('official')) {
      return false;
    }
    
    // 현재 선택하려는 타입에 따라 판단
    switch (_selectedType!) {
      case LeaveType.annual:
      case LeaveType.official:
        // 연차/공가를 신청하려면 해당 날짜에 아무것도 없어야 함
        return existingTypes.isEmpty;
      case LeaveType.halfAm:
        // 오전반차를 신청하려면 오전반차가 없어야 함 (오후반차는 있어도 됨)
        return !existingTypes.contains('half_am') && !existingTypes.contains('halfAm');
      case LeaveType.halfPm:
        // 오후반차를 신청하려면 오후반차가 없어야 함 (오전반차는 있어도 됨)
        return !existingTypes.contains('half_pm') && !existingTypes.contains('halfPm');
      default:
        return existingTypes.isEmpty;
    }
  }

  /// 날짜 선택 처리 (최적화됨)
  void _onDayTapped(DateTime day) {
    // 유형 미선택 시 날짜 선택 차단
    if (_selectedType == null) {
      showBanner(
        '먼저 휴가 유형을 선택해주세요.',
        type: BannerType.warning,
      );
      return;
    }

    // 연차/공가가 신청된 날짜는 완전 비활성화
    if (_cachedDisabledDates?.any((d) => isSameDay(d, day)) ?? false) {
      showBanner(
        '이미 연차/공가가 신청된 날짜입니다.',
        type: BannerType.error,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // 반차 중복 체크
    if (!_canSelectDateForType(day)) {
      final existingTypes = _getLeaveTypesForDate(day);
      if (existingTypes.contains('half_am') || existingTypes.contains('halfAm')) {
        showBanner(
          '이미 오전반차가 신청된 날짜입니다.',
          type: BannerType.error,
          duration: const Duration(seconds: 2),
        );
      } else if (existingTypes.contains('half_pm') || existingTypes.contains('halfPm')) {
        showBanner(
          '이미 오후반차가 신청된 날짜입니다.',
          type: BannerType.error,
          duration: const Duration(seconds: 2),
        );
      } else {
        showBanner(
          '이미 신청된 날짜입니다.',
          type: BannerType.error,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    // 다른 휴가 유형으로 선택된 날짜 체크
    for (final type in LeaveType.values) {
      if (type != _selectedType &&
          _selectedDatesMap[type]?.any((d) => isSameDay(d, day)) == true) {
        showBanner(
          '다른 유형으로 이미 선택된 날짜입니다.',
          type: BannerType.warning,
          duration: const Duration(seconds: 2),
        );
        return;
      }
    }

    setState(() {
      // null 체크 추가
      _selectedDatesMap[_selectedType!] ??= {};

      if (_selectedDatesMap[_selectedType!]!.any((d) => isSameDay(d, day))) {
        _selectedDatesMap[_selectedType!]!.removeWhere((d) => isSameDay(d, day));
      } else {
        _selectedDatesMap[_selectedType!]!.add(day);
      }
    });
  }

  /// 날짜 칩에서 날짜 제거
  void _onDateRemoved(LeaveType type, DateTime date) {
    setState(() {
      _selectedDatesMap[type]?.remove(date);
    });
  }

  /// 휴가 유형 변경
  void _onTypeChanged(LeaveType? type) {
    setState(() {
      _selectedType = type;
    });
  }

  /// 사용 연차 계산 (메모이제이션)
  double get _usedDaysSum {
    double sum = 0;
    for (final type in LeaveType.values) {
      if (_selectedDatesMap.containsKey(type) &&
          _selectedDatesMap[type] != null) {
        sum += _selectedDatesMap[type]!.length * type.days;
      }
    }
    return sum;
  }

  /// 날짜가 하나라도 선택되었는지 확인
  bool get _hasSelectedDates {
    for (final dates in _selectedDatesMap.values) {
      if (dates.isNotEmpty) return true;
    }
    return false;
  }

  /// 제출 가능 여부
  bool get _canSubmit {
    return !_isSubmitting &&
        _hasSelectedDates &&
        _memoController.text.trim().isNotEmpty;
  }

  /// 신청 처리 (검증 포함)
  Future<void> _submitLeaveRequest() async {
    if (_isSubmitting) return; // 중복 제출 방지

    // 입력 검증
    final memoError = LeaveValidators.validateMemo(_memoController.text);
    if (memoError != null) {
      showBanner(
        memoError,
        type: BannerType.error,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final dateError = LeaveValidators.validateDates(_selectedDatesMap);
    if (dateError != null) {
      showBanner(
        dateError,
        type: BannerType.error,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;

      // 이메일 검증
      final emailError = LeaveValidators.validateEmail(userEmail);
      if (emailError != null) {
        showBanner(
          emailError,
          type: BannerType.error,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // 잔여 연차 검증
      final remainError = LeaveValidators.validateRemainingDays(
        leaveProvider.remainAnnual,
        _usedDaysSum,
      );
      if (remainError != null) {
        showBanner(
          remainError,
          type: BannerType.warning,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // 메모 정제
      final sanitizedMemo = LeaveValidators.sanitizeInput(_memoController.text);

      bool hasError = false;
      List<Future<void>> requestFutures = [];

      final typesToProcess = _selectedDatesMap.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => e.key);

      for (final type in typesToProcess) {
        final selectedDates = _selectedDatesMap[type]!.toList()..sort();

        // 연속된 날짜들을 구간으로 묶기
        List<List<DateTime>> ranges = _groupConsecutiveDates(selectedDates);

        // 각 구간별 요청을 Future 리스트에 추가
        for (final range in ranges) {
          requestFutures.add(
            leaveProvider
                .requestLeave(
                  userEmail: userEmail!,
                  type: type.dbValue,
                  startDate: range.first,
                  endDate: range.last,
                  reason: sanitizedMemo,
                )
                .catchError((e) {
                  // Debug code removed
                  hasError = true;
                  return Future.value();
                }),
          );
        }
      }

      // 모든 요청을 병렬로 처리
      if (requestFutures.isNotEmpty) {
        await Future.wait(requestFutures);
      }

      if (!hasError) {
        showBanner(
          '신청이 완료되었습니다.',
          type: BannerType.success,
          duration: const Duration(seconds: 3),
        );

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        showBanner(
          '신청 중 오류가 발생했습니다.',
          type: BannerType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// 연속된 날짜들을 구간으로 묶기
  List<List<DateTime>> _groupConsecutiveDates(List<DateTime> dates) {
    List<List<DateTime>> ranges = [];
    for (final d in dates) {
      if (ranges.isEmpty || d.difference(ranges.last.last).inDays > 1) {
        ranges.add([d]);
      } else {
        ranges.last.add(d);
      }
    }
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: AppColors.backgroundPrimary,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 배너
        buildBanner(),

        // 연차 유형 선택
        LeaveTypeSelectorWidget(
          selectedType: _selectedType,
          onTypeChanged: _onTypeChanged,
        ),
        const SizedBox(height: 18),

        Selector<LeaveProvider, Map<String, double>>(
          selector: (_, provider) => {
            'remain': provider.remainAnnual,
            'granted': provider.currentGrantedAnnual,
            'used': provider.usedAnnual,
            'currentYear': provider.getGrantedAnnualForYear(
              DateTime.now().year,
            ),
            'nextYear': provider.getGrantedAnnualForYear(
              DateTime.now().year + 1,
            ),
          },
          builder: (context, data, _) {
            final now = DateTime.now();
            return LeaveInfoCardWidget(
              remainAnnual: data['remain']!,
              grantedAnnual: data['granted']!,
              usedAnnual: data['used']! + _usedDaysSum,
              currentYear: now.year,
              nextYear: now.year + 1,
              currentYearGranted: data['currentYear']!,
              nextYearGranted: data['nextYear']!,
            );
          },
        ),
        const SizedBox(height: 20),

        Selector<LeaveProvider, List<Map<String, dynamic>>>(
          selector: (_, provider) => provider.myLeaves,
          builder: (context, myLeaves, _) {
            // 캐시 업데이트
            if (_cachedDisabledDates == null) {
              _updateDisabledDatesCache(myLeaves);
            }

            return LeaveCalendarWidget(
              selectedDatesMap: _selectedDatesMap,
              selectedType: _selectedType,
              myLeaves: myLeaves,
              onDayTapped: _onDayTapped,
            );
          },
        ),

        // 선택된 날짜 칩들
        LeaveDateChipsWidget(
          selectedDatesMap: _selectedDatesMap,
          onDateRemoved: _onDateRemoved,
        ),
        const SizedBox(height: 16),

        // 메모 입력
        LeaveMemoInputWidget(
          controller: _memoController,
          focusNode: _memoFocusNode,
          onChanged: (_) => setState(() {}),
          isRequired: true,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: AppBarTitle('연차 신청'),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _canSubmit ? _submitLeaveRequest : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color: _canSubmit ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _canSubmit ? AppShadows.smShadow : null,
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
                '신청하기',
                style: AppTextStyles.buttonPrimary(context).copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _canSubmit ? Colors.white : AppColors.textDisabled,
                ),
              ),
      ),
    );
  }
}

// LeaveType extension은 이미 models/leave_request.dart에 정의되어 있음
