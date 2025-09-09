import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'attendance/attendance_screen_router.dart';
import 'leave/leave_status_screen.dart';
import 'approval/approval_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/leave_provider.dart';
import '../providers/notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive_utils.dart';
import '../services/notification_service.dart';

// KeepAlive 위젯 정의
class KeepAlive extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const KeepAlive({super.key, required this.child, this.keepAlive = true});

  @override
  State<KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class MainTab extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? initialEmployee;
  final int? approvalSubTab; // 승인관리 화면의 서브탭 (0: 연차/출장, 1: 발주승인)

  // initialIndex를 안전하게 제한
  const MainTab({
    super.key,
    int initialIndex = 0,
    this.initialEmployee,
    this.approvalSubTab,
  }) : initialIndex = (initialIndex < 0
           ? 0
           : (initialIndex > 4 ? 0 : initialIndex));

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> with TickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  List<Widget>? _screens; // nullable로 변경

  @override
  void initState() {
    super.initState();
    // 초기 인덱스는 나중에 권한 확인 후 설정
    _currentIndex = 0; // 일단 0으로 초기화
    _pageController = PageController(
      initialPage: 0, // 일단 0으로 초기화
      keepPage: true, // 페이지 상태 유지
    );

    // 자동 로그인이나 알림에서 넘어온 경우 바로 설정
    if (widget.initialEmployee != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // 알림에서 넘어온 경우 attendance_role만 있을 수 있음
        if (widget.initialEmployee!.containsKey('attendance_role')) {
          userProvider.setEmployee(widget.initialEmployee!);
        } else {
          // 자동 로그인인 경우
          userProvider.setUser(
            id: widget.initialEmployee!['id'],
            name: widget.initialEmployee!['name'],
            email: widget.initialEmployee!['email'],
          );
          userProvider.setEmployee(widget.initialEmployee!);
        }

        // employee 정보가 설정되면 화면 다시 초기화
        _initializeScreens();
      });
    }

    // 화면 초기화를 먼저 하고 데이터는 나중에 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializeScreens();
      _loadEmployeeData();

      // NotificationProvider 초기화
      try {
        final notificationProvider = Provider.of<NotificationProvider>(
          context,
          listen: false,
        );
        await notificationProvider.initialize();
        if (kDebugMode) {
          if (kDebugMode) print('✅ NotificationProvider 초기화 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ NotificationProvider 초기화 실패: $e');
        }
      }

      // FCM 토큰 자동 갱신 (중요!)
      try {
        await NotificationService.refreshTokenAfterLogin();
        if (kDebugMode) {
          if (kDebugMode) print('✅ FCM 토큰 자동 갱신 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ FCM 토큰 갱신 실패: $e');
        }
      }
    });
  }

  Future<void> _loadEmployeeData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 이미 employee 정보가 있으면 스킵
      if (userProvider.employee != null) {
        return;
      }

      if (userProvider.email != null) {
        final employee = await Supabase.instance.client
            .from('employees')
            .select()
            .eq('email', userProvider.email!)
            .maybeSingle();

        if (employee != null && mounted) {
          userProvider.setEmployee(employee);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('직원 정보 로드 중 오류: $e');
      }
    }
  }

  // 모든 데이터를 새로고침하는 공통 함수 (현재 미사용 - 추후 활용 가능)
  // ignore: unused_element
  static Future<void> refreshAllData(BuildContext context) async {
    try {
      // Provider들 가져오기
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 모든 데이터 새로고침 (병렬 처리)
      await Future.wait([
        // 출퇴근 데이터
        attendanceProvider.forceRefreshAll(),
        // 연차 데이터
        if (userProvider.email != null) ...[
          leaveProvider.fetchAllLeaves(forceRefresh: true),
          leaveProvider.fetchMyLeaves(
            email: userProvider.email!,
            forceRefresh: true,
          ),
        ],
      ]);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 데이터가 새로고침되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('데이터 새로고침 중 오류: $e');
      }
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex && _pageController.hasClients) {
      setState(() => _currentIndex = index);
      _pageController.jumpToPage(index); // animateToPage 대신 jumpToPage 사용
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면이 초기화되지 않았으면 로딩 표시
    if (_screens == null) {
      // 초기화가 안 된 경우 여기서 즉시 초기화
      _initializeScreens();
      if (_screens == null) {
        return Scaffold(
          body: Container(
            color: const Color(0xFFF8F9FA),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      }
    }

    final userProvider = Provider.of<UserProvider>(context);
    return _buildMainContent(userProvider);
  }

  void _initializeScreens() {
    if (_screens != null) return; // 이미 초기화됨

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final List<dynamic> attendanceRoles =
        (employee?['attendance_role'] as List<dynamic>?) ?? [];

    // 승인관리 탭을 볼 수 있는 역할 확인
    final approvalRoles = [
      'admin',
      'superadmin',
      '개발3팀_manager',
      'CAD_manager',
      '개발팀_manager',
      '경영지원팀_manager',
      '연구소_manager',
    ];

    final showApprovalTab = attendanceRoles.any(
      (role) => approvalRoles.contains(role),
    );

    // 디버깅 정보 출력
    if (kDebugMode) {
      if (kDebugMode) print('🔍 Employee info: $employee');
      if (kDebugMode) print('🔍 Attendance roles: $attendanceRoles');
      if (kDebugMode) print('🔍 Show approval tab: $showApprovalTab');
      if (kDebugMode) {
        print('🔍 Requested initialIndex: ${widget.initialIndex}');
      }
    }

    setState(() {
      if (showApprovalTab) {
        // 승인 권한이 있는 사용자는 5개 탭 모두 표시
        _screens = [
          const AttendanceScreenRouter(), // 출석
          const LeaveStatusScreen(), // 연차/출장신청
          ApprovalScreen(initialMainTab: widget.approvalSubTab), // 승인관리
          const CalendarScreen(), // 달력
          const SettingsScreen(), // 설정
        ];

        // 권한이 있으면 요청된 인덱스 사용
        _currentIndex = widget.initialIndex;
        if (_currentIndex >= _screens!.length) {
          _currentIndex = 0;
        }
      } else {
        // 승인 권한이 없는 사용자는 4개 탭만 표시
        _screens = [
          const AttendanceScreenRouter(), // 출석
          const LeaveStatusScreen(), // 연차/출장신청
          const CalendarScreen(), // 달력
          const SettingsScreen(), // 설정
        ];

        // 권한이 없으면 인덱스 조정
        if (widget.initialIndex == 2) {
          // 승인 탭을 요청했지만 권한이 없으면 홈으로
          _currentIndex = 0;
        } else if (widget.initialIndex > 2) {
          // 인덱스 조정 (승인 탭이 없으므로 -1)
          _currentIndex = widget.initialIndex - 1;
        } else {
          _currentIndex = widget.initialIndex;
        }

        // 범위 체크
        if (_currentIndex >= _screens!.length) {
          _currentIndex = 0;
        }
      }
    });

    // PageController 업데이트
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
    } else {
      // PageController 재생성
      _pageController = PageController(
        initialPage: _currentIndex,
        keepPage: true,
      );
    }
  }

  Widget _buildMainContent(UserProvider userProvider) {
    final employee = userProvider.employee;
    final List<dynamic> attendanceRoles =
        (employee?['attendance_role'] as List<dynamic>?) ?? [];

    // 승인관리 탭을 볼 수 있는 역할 확인 (초기화와 동일하게)
    final approvalRoles = [
      'admin',
      'superadmin',
      '개발3팀_manager',
      'CAD_manager',
      '개발팀_manager',
      '경영지원팀_manager',
    ];

    final showApprovalTab = attendanceRoles.any(
      (role) => approvalRoles.contains(role),
    );

    final List<BottomNavigationBarItem> items = [];

    // 출퇴근 탭 (인덱스 0)
    items.add(
      BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.spacing(context, 6),
          ),
          child: Icon(
            Icons.access_time,
            color: _currentIndex == 0 ? const Color(0xFFFF9500) : Colors.grey,
          ),
        ),
        label: '',
      ),
    );

    // 휴가 탭 (인덱스 1)
    items.add(
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            Icons.beach_access,
            color: _currentIndex == 1 ? AppColors.primary : Colors.grey,
          ),
        ),
        label: '',
      ),
    );

    // 승인관리 탭 (attendance_role이 있는 경우만, 인덱스 2)
    if (showApprovalTab) {
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.check_circle,
              color: _currentIndex == 2 ? const Color(0xFF34C759) : Colors.grey,
            ),
          ),
          label: '',
        ),
      );
    }

    // 캘린더 탭 (동적 인덱스)
    final calendarIndex = showApprovalTab ? 3 : 2;
    items.add(
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            Icons.calendar_today,
            color: _currentIndex == calendarIndex
                ? const Color(0xFFFF3B30)
                : Colors.grey,
          ),
        ),
        label: '',
      ),
    );

    // 설정 탭 (동적 인덱스)
    final settingsIndex = showApprovalTab ? 4 : 3;
    items.add(
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            Icons.settings,
            color: _currentIndex == settingsIndex
                ? const Color(0xFF8E8E93)
                : Colors.grey,
          ),
        ),
        label: '',
      ),
    );

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (mounted) {
            setState(() => _currentIndex = index);
          }
        },
        // 모든 화면을 미리 로드하여 깨짐 방지
        allowImplicitScrolling: true,
        children: _screens!.asMap().entries.map((entry) {
          return RepaintBoundary(
            key: ValueKey('screen_${entry.key}'),
            child: KeepAlive(keepAlive: true, child: entry.value),
          );
        }).toList(),
      ),
      bottomNavigationBar: RepaintBoundary(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
            ),
            color: Colors.white,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 14,
            unselectedFontSize: 14,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            selectedIconTheme: IconThemeData(
              size: ResponsiveUtils.iconSize(context, 30),
            ),
            unselectedIconTheme: IconThemeData(
              size: ResponsiveUtils.iconSize(context, 30),
            ),
            items: items,
            elevation: 0, // 그림자 제거로 성능 향상
          ),
        ),
      ),
    );
  }
}
