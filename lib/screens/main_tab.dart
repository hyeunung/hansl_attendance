import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'attendance/attendance_screen_router.dart';
import 'leave/leave_status_screen.dart';
import 'approval/approval_screen.dart';
// import 'purchase/purchase_management_screen.dart'; // 제거됨
import 'receipts/receipts_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/leave_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/purchase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive_utils.dart';
import '../utils/user_role_helper.dart';
import '../services/notification_service.dart';
import '../services/badge_count_service.dart';

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
           : (initialIndex > 5 ? 0 : initialIndex));

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> with TickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  List<Widget>? _screens; // nullable로 변경
  bool _isInitialized = false; // 초기화 완료 여부 추가

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _pageController = PageController(
      initialPage: 0,
      keepPage: true,
    );

    // 빠른 초기화를 위해 즉시 화면 구성
    _quickInitialize();
    
    // 나머지 비동기 작업은 프레임 후에
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _quickInitialize() {
    // 빠른 화면 구성 (비동기 작업 없이)
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (widget.initialEmployee != null) {
      // 이미 employee 정보가 있으면 바로 설정
      if (widget.initialEmployee!.containsKey('email') && 
          widget.initialEmployee!['email'] != null) {
        userProvider.setUser(
          id: widget.initialEmployee!['id'],
          name: widget.initialEmployee!['name'],
          email: widget.initialEmployee!['email'],
        );
      }
      userProvider.setEmployee(widget.initialEmployee!);
    }
    
    // 화면 바로 초기화
    _initializeScreens();
  }
  
  Future<void> _initializeServices() async {
    // 비동기 서비스 초기화
    if (mounted) {
      // employee 데이터 로드가 필요한 경우
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (widget.initialEmployee == null && userProvider.employee == null) {
        await _loadEmployeeData();
      }

      // NotificationProvider 초기화
      try {
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(
            context,
            listen: false,
          );
          await notificationProvider.initialize();
        }
        // Debug code removed
      } catch (e) {
        // Debug code removed
      }

      try {
        await NotificationService.refreshTokenAfterLogin();
        // Debug code removed
      } catch (e) {
        // Debug code removed
      }

      // 배지 카운트 초기화 및 실시간 구독 설정
      try {
        await BadgeCountService.updateBadgeCount();
        BadgeCountService.setupRealtimeSubscription();
      } catch (e) {
        // Badge service error - silently fail
      }

      // 승인관리 데이터 미리 로드 (배지 즉시 표시를 위해)
      _preloadApprovalData();
    }
  }

  // 세션 체크 메서드 제거 - MainTab은 이미 인증된 상태에서만 생성됨
  // 앱 시작 시 main.dart에서 인증 체크 완료

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
      // Debug code removed
    }
  }

  // 승인관리 데이터 미리 로드 (배지 즉시 표시를 위해)
  void _preloadApprovalData() {
    if (!mounted) return;
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      
      // 권한 확인
      final employee = userProvider.employee;
      if (employee == null) return;
      
      final attendanceRoles = employee['attendance_role'] as List<dynamic>? ?? [];
      final purchaseRoles = employee['purchase_role'] as List<dynamic>? ?? [];
      
      // 연차/출장 승인 권한이 있으면 미리 로드
      if (UserRoleHelper.isAnyManager(attendanceRoles) || 
          UserRoleHelper.isSuperAdmin(attendanceRoles) ||
          UserRoleHelper.isAdmin(attendanceRoles)) {
        leaveProvider.fetchAllLeaves(forceRefresh: false).catchError((e) {
          // 실패해도 UI에 영향 없음
        });
      }
      
      // 발주 승인 권한이 있으면 미리 로드
      if (UserRoleHelper.hasPurchaseApprovalAuth(purchaseRoles)) {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        purchaseProvider.fetchPendingPurchases(employee: employee).catchError((e) {
          // 실패해도 UI에 영향 없음
        });
      }
    } catch (e) {
      // 에러 발생해도 앱 동작에 영향 없음
    }
  }

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

      final futures = <Future<void>>[
        // 출퇴근 데이터
        attendanceProvider.forceRefreshAll(),
      ];
      
      // 연차 데이터
      if (userProvider.email != null) {
        futures.addAll([
          leaveProvider.fetchAllLeaves(forceRefresh: true),
          leaveProvider.fetchMyLeaves(
            email: userProvider.email!,
            forceRefresh: true,
          ),
        ]);
      }
      
      await Future.wait(futures);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 데이터가 새로고침되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Debug code removed
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex && _pageController.hasClients) {
      // 한 번의 setState로 통합
      setState(() {
        _currentIndex = index;
      });
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
    // 초기화가 완료되지 않았으면 빈 컨테이너 (깜빡임 방지)
    if (!_isInitialized || _screens == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    final userProvider = Provider.of<UserProvider>(context);
    return _buildMainContent(userProvider);
  }

  void _initializeScreens() {
    // Debug print removed
    if (_screens != null && _isInitialized) {
      // Debug print removed
      return; // 이미 초기화됨
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    // Debug print removed
final List<dynamic> attendanceRoles =
        (employee?['attendance_role'] as List<dynamic>?) ?? [];
    final List<dynamic> purchaseRoles =
        (employee?['purchase_role'] as List<dynamic>?) ?? [];
    // Debug print removed
// Debug print removed
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
    
    // lead buyer 권한 확인
    final isLeadBuyer = UserRoleHelper.isPureLeadBuyer(purchaseRoles);
    
    // app_admin 권한 확인 (영수증 탭용)
    final isAppAdmin = UserRoleHelper.isAppAdmin(purchaseRoles);

    // 디버깅 정보 출력
    // Debug code removed

    setState(() {
      if (isAppAdmin) {
        // app_admin: 모든 탭 표시 (영수증 탭 포함)
        _screens = [
          const AttendanceScreenRouter(), // 출석
          const LeaveStatusScreen(), // 연차/출장신청
          showApprovalTab ? ApprovalScreen(initialMainTab: widget.approvalSubTab) : const ApprovalScreen(), // 승인관리
          const ReceiptsScreen(), // 영수증 관리
          const CalendarScreen(), // 달력
          const SettingsScreen(), // 설정
        ];
      } else if (isLeadBuyer && !showApprovalTab) {
        // lead buyer 권한만 있고 승인권한이 없는 경우 (영수증 탭 제외)
        _screens = [
          const AttendanceScreenRouter(), // 출석
          const LeaveStatusScreen(), // 연차/출장신청
          const ApprovalScreen(), // 승인관리 (lead buyer는 구매대기와 입고대기 탭만 표시)
          const CalendarScreen(), // 달력
          const SettingsScreen(), // 설정
        ];
      } else if (showApprovalTab) {
        // 승인권한이 있는 경우 (영수증 탭 제외)
        _screens = [
          const AttendanceScreenRouter(), // 출석
          const LeaveStatusScreen(), // 연차/출장신청
          ApprovalScreen(initialMainTab: widget.approvalSubTab), // 승인관리 (입고현황 포함)
          const CalendarScreen(), // 달력
          const SettingsScreen(), // 설정
        ];
      } else {
        // 일반 사용자 (영수증 탭 제외)
        _screens = [
          const AttendanceScreenRouter(), // 출석
          const LeaveStatusScreen(), // 연차/출장신청
          const ApprovalScreen(), // 입고현황 (일반 직원은 입고대기 탭만 표시)
          const CalendarScreen(), // 달력
          const SettingsScreen(), // 설정
        ];

      }
      
      // 현재 인덱스 설정
      _currentIndex = widget.initialIndex;

      // 범위 체크
      if (_currentIndex >= _screens!.length) {
        _currentIndex = 0;
      }
      
      // 초기화 완료
      _isInitialized = true;
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
    final List<dynamic> purchaseRoles =
        (employee?['purchase_role'] as List<dynamic>?) ?? [];

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
    
    // lead buyer 권한 확인
    final isLeadBuyer = UserRoleHelper.isPureLeadBuyer(purchaseRoles);
    
    // app_admin 권한 확인 (영수증 탭용)
    final isAppAdmin = UserRoleHelper.isAppAdmin(purchaseRoles);

    final List<BottomNavigationBarItem> items = [];

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

    // 3번째 탭: 승인관리 또는 구매관리
    if (isLeadBuyer) {
      // lead buyer는 구매/입고관리 탭
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.shopping_cart,
              color: _currentIndex == 2 ? const Color(0xFF9C27B0) : Colors.grey,
            ),
          ),
          label: '',
        ),
      );
    } else {
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              showApprovalTab ? Icons.check_circle : Icons.inventory_2,
              color: _currentIndex == 2 ? (showApprovalTab ? const Color(0xFF34C759) : const Color(0xFF007AFF)) : Colors.grey,
            ),
          ),
          label: '',
        ),
      );
    }

    // app_admin만 영수증 탭 표시
    if (isAppAdmin) {
      // 4번째 탭: 영수증 관리 (app_admin 전용)
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.receipt_long,
              color: _currentIndex == 3 ? const Color(0xFFFF9500) : Colors.grey,
            ),
          ),
          label: '',
        ),
      );
      
      // 5번째 탭: 달력
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.calendar_today,
              color: _currentIndex == 4
                  ? const Color(0xFFFF3B30)
                  : Colors.grey,
            ),
          ),
          label: '',
        ),
      );

      // 6번째 탭: 설정
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.settings,
              color: _currentIndex == 5
                  ? const Color(0xFF8E8E93)
                  : Colors.grey,
            ),
          ),
          label: '',
        ),
      );
    } else {
      // 일반 사용자: 영수증 탭 제외 (5개 탭)
      // 4번째 탭: 달력
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.calendar_today,
              color: _currentIndex == 3
                  ? const Color(0xFFFF3B30)
                  : Colors.grey,
            ),
          ),
          label: '',
        ),
      );

      // 5번째 탭: 설정
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.settings,
              color: _currentIndex == 4
                  ? const Color(0xFF8E8E93)
                  : Colors.grey,
            ),
          ),
          label: '',
        ),
      );
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (mounted && index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });
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
            selectedLabelStyle: ResponsiveUtils.getTextStyle(context, fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: ResponsiveUtils.getTextStyle(context, fontSize: 12, fontWeight: FontWeight.w600),
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
