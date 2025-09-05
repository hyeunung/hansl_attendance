import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/leave_request.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../theme/app_colors.dart';
import '../../utils/logger.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';

class AnnualLeaveRequestScreen extends StatefulWidget {
  const AnnualLeaveRequestScreen({super.key});

  @override
  State<AnnualLeaveRequestScreen> createState() => _AnnualLeaveRequestScreenState();
}

class _AnnualLeaveRequestScreenState extends State<AnnualLeaveRequestScreen> {
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _memoFocusNode = FocusNode();
  LeaveType _selectedType = LeaveType.annual;
  bool _dropdownOpen = false;
  bool _localeInitialized = false;
  final List<LeaveType> _leaveTypes = [
    LeaveType.annual,
    LeaveType.halfAm,
    LeaveType.halfPm,
    LeaveType.official,
  ];
  // leaveType별 날짜 관리
  final Map<LeaveType, Set<DateTime>> _selectedDatesMap = {
    LeaveType.annual: {},
    LeaveType.halfAm: {},
    LeaveType.halfPm: {},
    LeaveType.official: {},
  };
  String? _bannerMessage;
  Color _bannerColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    // 한글 날짜 포맷 초기화
    initializeDateFormatting('ko_KR', null).then((_) {
      if (mounted) {
        setState(() {
          _localeInitialized = true;
        });
      }
    });
    // 화면 진입시 DB에서 연차 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = context.read<UserProvider>();
      final leaveProvider = context.read<LeaveProvider>();
      if (userProvider.email != null) {
        AppLogger.debug('연차 신청 화면: DB에서 연차 정보 로드 시작', AppLogger.maskSensitive(userProvider.email!));
        await leaveProvider.fetchMyLeaves(email: userProvider.email!, forceRefresh: true);
        // 공휴일 데이터도 로드
        await leaveProvider.fetchHolidays(forceRefresh: true);

        // 공휴일 데이터 로드 확인
        print('🎌 연차신청화면 - 공휴일 데이터: ${leaveProvider.holidays.length}개');
        if (leaveProvider.holidays.isNotEmpty) {
          print('샘플 공휴일: ${leaveProvider.holidays.take(3).map((h) => h['name']).join(', ')}');
          // 1월 1일이 공휴일인지 확인
          final newYear = DateTime(2025, 1, 1);
          print('2025년 1월 1일 공휴일 여부: ${leaveProvider.isHoliday(newYear)}');
        } else {
          print('⚠️ 공휴일 데이터가 없습니다! 하드코딩 데이터를 사용해야 합니다.');
        }

        AppLogger.info('연차 정보 로드 완료', {
          '사용연차': leaveProvider.usedAnnual,
          '잔여연차': leaveProvider.remainAnnual,
          '공휴일': leaveProvider.holidays.length,
        });
      }
    });
  }

  @override
  void dispose() {
    _memoController.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  // leaveType별 파스텔톤 색상
  Color _typeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return const Color(0xFFB3D8FF); // 연파랑

      case LeaveType.halfAm:
        return const Color(0xFFFFE0B2); // 연주황
      case LeaveType.halfPm:
        return const Color(0xFFC8E6C9); // 연초록
      case LeaveType.official:
        return const Color(0xFFE0E0E0); // 연회색
      default:
        return Colors.black;
    }
  }

  // leaveType별 CustomPainter (연차: 동그라미, 오전/오후반차: 반달)
  Widget _buildDayMarker(DateTime day, LeaveType type) {
    if (type == LeaveType.annual || type == LeaveType.official) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _typeColor(type), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    } else if (type == LeaveType.halfAm) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: CustomPaint(
            size: const Size(36, 36),
            painter: _HalfCirclePainter(_typeColor(type), true),
            child: Center(
              child: Text(
                '${day.day}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    } else if (type == LeaveType.halfPm) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: CustomPaint(
            size: const Size(36, 36),
            painter: _HalfCirclePainter(_typeColor(type), false),
            child: Center(
              child: Text(
                '${day.day}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // leaveType별 날짜 Chip
  Widget _buildDateChip(DateTime d, LeaveType type) {
    return Chip(
      label: Text(DateFormat('yyyy.MM.dd').format(d)),
      backgroundColor: _typeColor(type).withValues(alpha: 0.15),
      labelStyle: TextStyle(color: _typeColor(type), fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // 달력에서 날짜 선택/해제
  void _onDayTapped(DateTime day, List<Map<String, dynamic>> myLeaves) {
    // 주말 체크
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주말은 선택할 수 없습니다.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 공휴일 체크
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    if (leaveProvider.isHoliday(day)) {
      final holidayInfo = leaveProvider.getHolidayInfo(day);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${holidayInfo?['name'] ?? '공휴일'}은 선택할 수 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 이미 신청된 날짜는 선택 불가
    final Set<DateTime> disabledDates = myLeaves
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
    if (disabledDates.any((d) => isSameDay(d, day))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 신청된 날짜입니다.'), backgroundColor: Colors.red));
      return;
    }
    // 다른 leaveType에 이미 선택된 날짜는 선택 불가
    for (final type in _leaveTypes) {
      if (type != _selectedType && _selectedDatesMap[type]!.any((d) => isSameDay(d, day))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다른 유형으로 이미 선택된 날짜입니다.'), backgroundColor: Colors.red),
        );
        return;
      }
    }
    setState(() {
      if (_selectedDatesMap[_selectedType]!.any((d) => isSameDay(d, day))) {
        _selectedDatesMap[_selectedType]!.removeWhere((d) => isSameDay(d, day));
      } else {
        _selectedDatesMap[_selectedType]!.add(day);
      }
    });
  }

  // 사용연차 합산
  double get _usedDaysSum {
    double sum = 0;
    for (final type in _leaveTypes) {
      sum += _selectedDatesMap[type]!.length * type.days;
    }
    return sum;
  }

  Widget _buildBanner() {
    if (_bannerMessage == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _bannerColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: _bannerColor.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Text(
        _bannerMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  void _showBanner(String msg, {bool error = false}) {
    setState(() {
      _bannerMessage = msg;
      _bannerColor = error ? Colors.red : AppColors.primary;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LeaveProvider, UserProvider>(
      builder: (context, leaveProvider, userProvider, _) {
        final now = DateTime.now();
        final thisYear = now.year;
        final nextYear = now.year + 1;
        final remainAnnual = leaveProvider.remainAnnual;
        final grantedAnnual = leaveProvider.currentGrantedAnnual;
        final myLeaves = leaveProvider.myLeaves;
        final employee = userProvider.employee; // employee 정보(입사일 등)
        int hireYear = 0;
        // int yearsOfService = 0; // 향후 근속연수 기반 기능용
        if (employee != null && employee['join_date'] != null) {
          hireYear = DateTime.parse(employee['join_date']).year;
          // yearsOfService = (thisYear - hireYear); // 향후 근속연수 기반 기능용
        }

        final thisYearGranted = leaveProvider.getGrantedAnnualForYear(thisYear);
        final nextYearGranted = leaveProvider.getGrantedAnnualForYear(nextYear);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('연차 신청', style: AppTextStyles.appBarTitle(context)),
          ),
          backgroundColor: const Color(0xFFF6F7FA),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBanner(),
                // 드롭다운: 연차 유형 선택
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [AppShadows.card],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedType.label,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Icon(
                              _dropdownOpen ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: _dropdownOpen ? (_leaveTypes.length * 48.0) : 0,
                      curve: Curves.easeInOut,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: _leaveTypes.map((type) {
                            return Material(
                              color: Colors.white,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedType = type;
                                    _dropdownOpen = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  child: Text(type.label, style: const TextStyle(fontSize: 18)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 파란 카드
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '신청 가능',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$remainAnnual일',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '/ $grantedAnnual',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• $thisYear.01.01 ~ $thisYear.12.31   $thisYearGranted일   >',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      Text(
                        '• $nextYear.01.01 ~ $nextYear.12.31   $nextYearGranted일   >',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 날짜 입력 및 달력
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [AppShadows.card],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '날짜',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                          const SizedBox(width: 12),
                          // 사용연차는 DB에서 가져온 실제 사용한 연차 + 현재 선택한 날짜
                          Text(
                            '사용연차 : ${(leaveProvider.usedAnnual + _usedDaysSum) % 1 == 0 ? (leaveProvider.usedAnnual + _usedDaysSum).toInt() : (leaveProvider.usedAnnual + _usedDaysSum)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 210, // 캘린더 높이 더 줄임 (overflow 방지)
                        child: TableCalendar(
                          locale: 'ko_KR',
                          firstDay: DateTime(now.year, 1, 1),
                          lastDay: DateTime(now.year + 1, 12, 31),
                          focusedDay: DateTime.now(),
                          selectedDayPredicate: (day) {
                            for (final type in _leaveTypes) {
                              if (_selectedDatesMap[type]!.any((d) => isSameDay(d, day)))
                                return true;
                            }
                            return false;
                          },
                          onDaySelected: (selectedDay, _) => _onDayTapped(selectedDay, myLeaves),
                          calendarStyle: CalendarStyle(
                            isTodayHighlighted: true,
                            selectedDecoration: const BoxDecoration(),
                            todayDecoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            disabledTextStyle: TextStyle(color: Colors.grey.shade400),
                            cellMargin: const EdgeInsets.all(2),
                            cellPadding: const EdgeInsets.all(0),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            weekendStyle: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          enabledDayPredicate: (day) {
                            // 주말 체크 (토요일, 일요일)
                            if (day.weekday == DateTime.saturday ||
                                day.weekday == DateTime.sunday) {
                              return false;
                            }

                            // 공휴일 체크
                            if (leaveProvider.isHoliday(day)) {
                              return false;
                            }

                            final Set<DateTime> disabledDates = myLeaves
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
                            if (disabledDates.any((d) => isSameDay(d, day))) return false;
                            for (final type in _leaveTypes) {
                              if (type != _selectedType &&
                                  _selectedDatesMap[type]!.any((d) => isSameDay(d, day)))
                                return false;
                            }
                            return true;
                          },
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            headerPadding: const EdgeInsets.symmetric(vertical: 4),
                            titleTextStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            titleTextFormatter: (date, locale) {
                              // 완전 하드코딩으로 한글 월 표시
                              const months = [
                                '1월',
                                '2월',
                                '3월',
                                '4월',
                                '5월',
                                '6월',
                                '7월',
                                '8월',
                                '9월',
                                '10월',
                                '11월',
                                '12월',
                              ];
                              return '${date.year}년 ${months[date.month - 1]}';
                            },
                            leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.black),
                            rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.black),
                          ),
                          calendarFormat: CalendarFormat.month,
                          // 좌우 스와이프만 허용, 상하는 전체 화면 스크롤로 전달
                          pageJumpingEnabled: true,
                          availableGestures: AvailableGestures.horizontalSwipe,
                          sixWeekMonthsEnforced: false, // 높이 유연하게 조정
                          daysOfWeekHeight: 28,
                          calendarBuilders: CalendarBuilders(
                            dowBuilder: (context, day) {
                              final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
                              final text = weekdays[day.weekday % 7];

                              return Center(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: day.weekday == DateTime.sunday
                                        ? Colors.red
                                        : day.weekday == DateTime.saturday
                                        ? Colors.blue
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                            defaultBuilder: (context, day, focusedDay) {
                              // 공휴일인 경우 빨간색으로 표시
                              if (leaveProvider.isHoliday(day)) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              // 주말인 경우 색상 구분
                              if (day.weekday == DateTime.sunday) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              if (day.weekday == DateTime.saturday) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                            disabledBuilder: (context, day, focusedDay) {
                              // 비활성화된 날짜 스타일 (주말, 공휴일, 이미 신청된 날짜)
                              Color textColor = Colors.grey.shade400;

                              // 공휴일은 빨간색으로 유지
                              if (leaveProvider.isHoliday(day)) {
                                textColor = Colors.red.shade300;
                              }
                              // 일요일
                              else if (day.weekday == DateTime.sunday) {
                                textColor = Colors.red.shade300;
                              }
                              // 토요일
                              else if (day.weekday == DateTime.saturday) {
                                textColor = Colors.blue.shade300;
                              }

                              return Container(
                                margin: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                            markerBuilder: (context, day, events) {
                              LeaveType? type;
                              for (final t in _leaveTypes) {
                                if (_selectedDatesMap[t]!.any((d) => isSameDay(d, day))) {
                                  type = t;
                                  break;
                                }
                              }
                              if (type != null) {
                                return Positioned(
                                  bottom: 1,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _typeColor(type),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                            todayBuilder: (context, day, focusedDay) {
                              LeaveType? type;
                              for (final t in _leaveTypes) {
                                if (_selectedDatesMap[t]!.any((d) => isSameDay(d, day))) {
                                  type = t;
                                  break;
                                }
                              }
                              if (type != null) {
                                return _buildDayMarker(day, type);
                              }
                              return Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_leaveTypes.any((type) => _selectedDatesMap[type]!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final type in _leaveTypes)
                          for (final d
                              in (_selectedDatesMap[type]!.toList()
                                ..sort((a, b) => a.compareTo(b))))
                            _buildDateChip(d, type),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // 사유 입력
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [AppShadows.card],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text('사유', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF6F7FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: TextField(
                          controller: _memoController,
                          focusNode: _memoFocusNode,
                          decoration: const InputDecoration(
                            hintText: '사유를 입력하세요',
                            border: InputBorder.none,
                          ),
                          maxLines: 3,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_memoController.text.trim().isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0, left: 4.0),
                          child: Text(
                            '사유는 필수 입력 항목입니다.',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: AnimatedPadding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(top: 16, bottom: 16, left: 20, right: 20),
                child: Row(
                  children: [
                    if (MediaQuery.of(context).viewInsets.bottom > 0)
                      SizedBox(width: 48), // 왼쪽 공간(키보드 올라왔을 때만)
                    Expanded(
                      child: GestureDetector(
                        onTap: (_usedDaysSum > 0 && _memoController.text.trim().isNotEmpty)
                            ? () async {
                                final leaveProvider = Provider.of<LeaveProvider>(
                                  context,
                                  listen: false,
                                );
                                final userProvider = Provider.of<UserProvider>(
                                  context,
                                  listen: false,
                                );
                                final userEmail = userProvider.email;
                                if (userEmail == null || userEmail.isEmpty) {
                                  if (mounted) {
                                    _showBanner('로그인 정보가 없습니다. 다시 로그인 해주세요.', error: true);
                                  }
                                  return;
                                }
                                bool hasError = false;
                                for (final type in _leaveTypes) {
                                  final selectedDates = _selectedDatesMap[type]!.toList()..sort();
                                  if (selectedDates.isEmpty) continue;
                                  // 연속 구간별로 묶기
                                  List<List<DateTime>> ranges = [];
                                  for (final d in selectedDates) {
                                    if (ranges.isEmpty ||
                                        d.difference(ranges.last.last).inDays > 1) {
                                      ranges.add([d]);
                                    } else {
                                      ranges.last.add(d);
                                    }
                                  }
                                  for (final range in ranges) {
                                    final start = range.first;
                                    final end = range.last;
                                    try {
                                      await leaveProvider.requestLeave(
                                        userEmail: userEmail,
                                        type: type.dbValue,
                                        startDate: start,
                                        endDate: end,
                                        reason: _memoController.text.trim(),
                                      );
                                    } catch (e) {
                                      hasError = true;
                                    }
                                  }
                                }
                                if (!hasError) {
                                  if (mounted) {
                                    _showBanner('신청이 완료되었습니다.');
                                    Future.delayed(const Duration(seconds: 2), () {
                                      if (!context.mounted) return;
                                      if (mounted) Navigator.pop(context);
                                    });
                                  }
                                } else {
                                  if (mounted) {
                                    _showBanner('신청 중 오류가 발생했습니다.', error: true);
                                  }
                                }
                              }
                            : null,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: (_usedDaysSum > 0) ? AppColors.primaryGradient : null,
                            color: (_usedDaysSum > 0) ? null : const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [if (_usedDaysSum > 0) AppShadows.button],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '신청하기',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: (_usedDaysSum > 0) ? Colors.white : const Color(0xFFB0B0B0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (MediaQuery.of(context).viewInsets.bottom > 0)
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: () => FocusScope.of(context).unfocus(), // 키보드 내리기
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// 반달(위/아래) CustomPainter - arc 중심 (18,18)로 정확히 중앙에 오도록
class _HalfCirclePainter extends CustomPainter {
  final Color color;
  final bool isTop;
  _HalfCirclePainter(this.color, this.isTop);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path();
    if (isTop) {
      path.moveTo(center.dx - radius, center.dy);
      path.arcTo(rect, -3.14, 3.14, false);
      path.close();
    } else {
      path.moveTo(center.dx - radius, center.dy);
      path.arcTo(rect, 0, 3.14, false);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
