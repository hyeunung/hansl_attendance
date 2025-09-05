import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../providers/purchase_provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/user_provider.dart';
import '../../widgets/purchase/purchase_approval_widget.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late TabController _mainTabController; // 메인 탭 (연차/출장, 발주승인)
  late TabController _subTabController; // 서브 탭 (대기중, 처리완료)
  bool _hasPurchaseApprovalAuth = false; // 발주 승인 권한 여부

  @override
  void initState() {
    super.initState();
    // 초기값은 1개 탭으로 설정, build에서 권한 확인 후 조정
    _mainTabController = TabController(length: 1, vsync: this);
    _subTabController = TabController(length: 2, vsync: this);

    // TabController 리스너 추가 - 탭 변경시 UI 업데이트
    _mainTabController.addListener(() {
      if (mounted) setState(() {});
    });
    _subTabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 전환 시마다 새로고침하지 않도록 주석 처리
    // 필요 시 수동 새로고침 버튼 사용
    // _loadData();
  }

  void _loadData() {
    // 첫 빌드 후에 데이터 로드 - 비동기로 변경하여 UI 블로킹 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        if (kDebugMode) {
          debugPrint('🔄 승인 화면 새로고침 시작');
          debugPrint('📋 현재 사용자 employee 데이터: ${userProvider.employee}');
          debugPrint('📋 purchase_role: ${userProvider.employee?['purchase_role']}');
          debugPrint('📋 _hasPurchaseApprovalAuth: $_hasPurchaseApprovalAuth');
        }

        // 연차 데이터 비동기 로드 (await 제거로 UI 즉시 렌더링)
        leaveProvider.fetchAllLeaves(forceRefresh: true).then((_) {
          if (kDebugMode) debugPrint('✅ 연차 데이터 로드 완료');
        }).catchError((e) {
          if (kDebugMode) debugPrint('❌ 연차 데이터 로드 실패: $e');
        });
        
        // 발주 데이터 비동기 로드 (권한이 있는 경우)
        if (_hasPurchaseApprovalAuth) {
          if (kDebugMode) debugPrint('🔐 발주 데이터 로드 시작');
          purchaseProvider.fetchPendingPurchases(
            employee: userProvider.employee,
          ).then((_) {
            if (kDebugMode) debugPrint('✅ 발주 데이터 로드 완료');
          }).catchError((e) {
            if (kDebugMode) debugPrint('❌ 발주 데이터 로드 실패: $e');
          });
        } else {
          if (kDebugMode) debugPrint('⚠️ 발주 승인 권한 없음');
        }
      }
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final role = employee?['role'];
    final name = employee?['name'];
    final department = employee?['department'];
    final attendanceRoles = employee?['attendance_role'] as List<dynamic>? ?? [];
    final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];

    // purchase_role에 따른 발주 승인 권한 확인
    if (kDebugMode) {
      debugPrint('🔍 ApprovalScreen build - purchaseRoles 체크');
      debugPrint('📋 purchaseRoles: $purchaseRoles');
      debugPrint('📋 purchaseRoles 타입: ${purchaseRoles.runtimeType}');
      debugPrint('📋 purchaseRoles isEmpty: ${purchaseRoles.isEmpty}');
    }
    
    final bool hasPurchaseApproval = purchaseRoles.contains('middle_manager') ||
        purchaseRoles.contains('final_approver') ||
        purchaseRoles.contains('raw_material_manager') ||
        purchaseRoles.contains('consumable_manager') ||
        purchaseRoles.contains('app_admin');
    
    if (kDebugMode) {
      debugPrint('📋 hasPurchaseApproval: $hasPurchaseApproval');
    }
    
    // 탭 개수 조정 (초기화 시점과 다른 경우)
    if (_hasPurchaseApprovalAuth != hasPurchaseApproval) {
      _hasPurchaseApprovalAuth = hasPurchaseApproval;
      final tabCount = hasPurchaseApproval ? 2 : 1;
      
      if (kDebugMode) {
        debugPrint('🔄 탭 개수 조정 필요: $tabCount개 탭으로 변경');
      }
      
      // TabController 재생성 필요
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _mainTabController.dispose();
            _mainTabController = TabController(length: tabCount, vsync: this);
            _mainTabController.addListener(() {
              if (mounted) setState(() {});
            });
          });
          // 발주 데이터 로드 (setState 밖에서 실행)
          if (hasPurchaseApproval) {
            if (kDebugMode) debugPrint('🔐 권한 확인 후 발주 데이터 로드 시작');
            final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            purchaseProvider.fetchPendingPurchases(
              employee: userProvider.employee,
            );
          }
        }
      });
    }

    // attendance_role에 따른 권한 확인
    final bool isAdmin = attendanceRoles.contains('admin');
    final bool isSuperAdmin = attendanceRoles.contains('superadmin');
    final bool isAdminOrSuper = isAdmin || isSuperAdmin;
    final bool isDev3Manager = attendanceRoles.contains('개발3팀_manager');
    final bool isCadManager = attendanceRoles.contains('CAD_manager'); // 대문자로 수정!
    final bool isDevManager = attendanceRoles.contains('개발팀_manager');
    final bool isSupportManager = attendanceRoles.contains('경영지원팀_manager');
    final bool isLabManager = attendanceRoles.contains('연구소_manager');
    final bool isManager =
        isDev3Manager || isCadManager || isDevManager || isSupportManager || isLabManager;
    final bool hasApprovalRole = isAdminOrSuper || isManager;

    // attendance_role에 따른 승인 가능 부서 매핑
    final List<String> approvalDepartments = [];
    if (isAdminOrSuper) {
      // admin/superadmin은 모든 부서 승인 가능
      approvalDepartments.addAll(['개발1팀', '개발2팀', '개발3팀', 'CAD', '경영지원팀', '연구소', '개발팀']);
    } else {
      if (isDev3Manager) approvalDepartments.add('개발3팀');
      if (isCadManager) approvalDepartments.add('CAD');
      if (isDevManager) approvalDepartments.addAll(['개발1팀', '개발2팀']);
      if (isSupportManager) approvalDepartments.add('경영지원팀');
      if (isLabManager) approvalDepartments.add('연구소');
    }

    // 매니저 타입 확인용 attendance_role 리스트
    final List<String> managerRoles = [
      '개발3팀_manager',
      'CAD_manager',
      '개발팀_manager',
      '경영지원팀_manager',
      '연구소_manager',
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('승인 관리', style: AppTextStyles.appBarTitle(context)),
            if (isAdminOrSuper) ...[
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 8),
                  vertical: ResponsiveUtils.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: ResponsiveUtils.iconSize(context, 16),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                    Text(
                      'ADMIN',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {
              if (kDebugMode) debugPrint('🔄 수동 새로고침 버튼 클릭');
              _loadData();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '새로고침',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          if (kDebugMode) debugPrint('🔄 Consumer 빌드 - allLeaves 수: ${provider.allLeaves.length}');
          List<Map<String, dynamic>> allLeaves = provider.allLeaves;

          if (kDebugMode) {
            debugPrint('🔍 ApprovalScreen - 전체 데이터 수: ${allLeaves.length}');
            debugPrint('👤 현재 사용자: $name (role: $role)');
            debugPrint('🏢 현재 부서: $department');
            debugPrint('🔑 Attendance Roles: $attendanceRoles');
            debugPrint('✅ 승인 가능 부서: $approvalDepartments');
            debugPrint('🔧 hasApprovalRole: $hasApprovalRole');
            debugPrint('🔧 isManager: $isManager');
            debugPrint('🔧 isAdminOrSuper: $isAdminOrSuper');

            // 처음 몇 개 데이터의 상태 출력
            if (allLeaves.isNotEmpty) {
              debugPrint('📋 전체 데이터 샘플:');
              for (int i = 0; i < (allLeaves.length > 5 ? 5 : allLeaves.length); i++) {
                final leave = allLeaves[i];
                final emp = leave['employees'];
                debugPrint(
                  '  ${i + 1}. ID: ${leave['id']}, 상태: ${leave['status']}, 신청자: ${leave['user_email']}, 부서: ${emp is Map ? emp['department'] : 'Unknown'}',
                );
              }
            }
          }

          // attendance_role에 따른 필터링
          if (hasApprovalRole) {
            final beforeFilter = allLeaves.length;

            if (attendanceRoles.contains('superadmin')) {
              // SuperAdmin: 모든 직원의 신청 표시 (필터링 없음)
              if (kDebugMode) debugPrint('👑 SuperAdmin: 모든 직원의 신청 표시 ($beforeFilter개)');
            } else if (attendanceRoles.contains('admin')) {
              // Admin: superadmin을 제외한 모든 신청 표시
              allLeaves = allLeaves.where((l) {
                final emp = l['employees'];
                final leaveAttendanceRoles = emp is Map
                    ? (emp['attendance_role'] as List<dynamic>? ?? [])
                    : [];
                return !leaveAttendanceRoles.contains('superadmin');
              }).toList();
              if (kDebugMode)
                debugPrint(
                  '👑 Admin 필터링: $beforeFilter -> ${allLeaves.length} (superadmin 제외한 모든 신청)',
                );
            } else if (isManager) {
              // Manager: 해당 부서의 일반 직원만 표시 (매니저 제외, 자신 포함)
              allLeaves = allLeaves.where((l) {
                final emp = l['employees'];
                final leaveDept = emp is Map ? emp['department'] : null;
                final leaveEmail = l['user_email'] ?? '';
                final leaveAttendanceRoles = emp is Map
                    ? (emp['attendance_role'] as List<dynamic>? ?? [])
                    : [];

                if (kDebugMode && leaveEmail == 'test@hansl.com') {
                  debugPrint('🔍 test@hansl.com 필터링 디버그:');
                  debugPrint('  - leaveEmail: $leaveEmail');
                  debugPrint('  - leaveDept: $leaveDept');
                  debugPrint('  - leaveAttendanceRoles: $leaveAttendanceRoles');
                  debugPrint('  - userProvider.email: ${userProvider.email}');
                  debugPrint('  - approvalDepartments: $approvalDepartments');
                }

                // 자신의 연차는 제외 (스스로 승인 불가)
                if (leaveEmail == userProvider.email) {
                  if (kDebugMode && leaveEmail == 'test@hansl.com') debugPrint('  ❌ 자신의 연차라서 제외');
                  return false;
                }

                // superadmin의 연차는 제외 (부서 매니저가 승인 불가)
                if (leaveAttendanceRoles.contains('superadmin')) {
                  if (kDebugMode && leaveEmail == 'test@hansl.com')
                    debugPrint('  ❌ superadmin이라서 제외');
                  return false;
                }

                // admin의 연차도 제외 (부서 매니저가 승인 불가)
                if (leaveAttendanceRoles.contains('admin')) {
                  if (kDebugMode && leaveEmail == 'test@hansl.com') debugPrint('  ❌ admin이라서 제외');
                  return false;
                }

                // 다른 매니저의 연차는 제외 (매니저끼리 승인 불가)
                final hasManagerRole = managerRoles.any(
                  (role) => leaveAttendanceRoles.contains(role),
                );
                if (hasManagerRole) {
                  if (kDebugMode && leaveEmail == 'test@hansl.com') debugPrint('  ❌ 매니저라서 제외');
                  return false;
                }

                // 해당 부서 일반 직원만 표시
                final shouldShow = leaveDept != null && approvalDepartments.contains(leaveDept);
                if (kDebugMode && leaveEmail == 'test@hansl.com') {
                  debugPrint('  - shouldShow: $shouldShow');
                  if (shouldShow) {
                    debugPrint('  ✅ 표시됨');
                  } else {
                    debugPrint('  ❌ 부서가 맞지 않아서 제외');
                  }
                }
                return shouldShow;
              }).toList();
              if (kDebugMode)
                debugPrint(
                  '🏢 Manager 필터링: $beforeFilter -> ${allLeaves.length} (부서: $approvalDepartments, 매니저/admin/superadmin 제외)',
                );
            }
          } else {
            // 승인 권한이 없으면 비워서 표시
            allLeaves = [];
            if (kDebugMode) debugPrint('⚠️ 승인 권한 없음 - 데이터 표시 안 함');
          }

          final pending = allLeaves.where((l) => l['status'] == 'pending').toList();

          // Admin/SuperAdmin은 전체 직원의 처리완료 건을 보여줌
          List<Map<String, dynamic>> done;
          if (isAdminOrSuper) {
            // Admin/SuperAdmin: 전체 직원의 처리완료 건을 보여줌
            done = provider.allLeaves.where((l) => l['status'] != 'pending').toList();
            if (kDebugMode) {
              debugPrint('👑 Admin/SuperAdmin: 전체 처리완료 건 표시 (${done.length}개)');
            }
          } else {
            // Manager: 현재 필터링된 데이터에서만 처리완료 건 표시
            done = allLeaves.where((l) => l['status'] != 'pending').toList();
          }

          final now = DateTime.now();
          final thisMonth = now.month;
          final thisYear = now.year;

          // 이번 달에 처리된 항목만 필터링 (updated_at 기준)
          final thisMonthDone = done.where((l) {
            // updated_at이 있으면 사용, 없으면 created_at 사용
            final dateStr = l['updated_at'] ?? l['created_at'];
            if (dateStr == null) return false;
            final date = DateTime.parse(dateStr);
            // 승인/반려가 이번 달에 처리된 건만
            return date.year == thisYear && date.month == thisMonth && l['status'] != 'pending';
          }).toList();

          if (kDebugMode)
            debugPrint(
              '📊 최종 결과: pending=${pending.length}, done=${done.length}, thisMonth=${thisMonthDone.length}',
            );

          // pending 데이터 상세 출력
          for (final leave in pending) {
            final emp = leave['employees'];
            final dept = emp is Map ? emp['department'] : 'Unknown';
            if (kDebugMode)
              debugPrint(
                '⏳ Pending: ${leave['name']} ($dept) - ${leave['type']} (${leave['start_date']} ~ ${leave['end_date']})',
              );
          }

          return Column(
            children: [
              // 통합된 탭 디자인 - Segmented Control 스타일
              Container(
                margin: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 4)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                ),
                child: Row(
                  children: [
                    // 연차/출장 탭
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _mainTabController.animateTo(0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 14),
                          ),
                          decoration: BoxDecoration(
                            color: _mainTabController.index == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 10),
                            ),
                            boxShadow: _mainTabController.index == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: ResponsiveUtils.iconSize(context, 18),
                                color: _mainTabController.index == 0
                                    ? AppColors.primary
                                    : const Color(0xFF8E8E93),
                              ),
                              SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                              Text(
                                '연차/출장',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 15,
                                  fontWeight: _mainTabController.index == 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _mainTabController.index == 0
                                      ? const Color(0xFF1C1C1E)
                                      : const Color(0xFF8E8E93),
                                ),
                              ),
                              if (_mainTabController.index == 0 && pending.isNotEmpty) ...[
                                SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.spacing(context, 6),
                                    vertical: ResponsiveUtils.spacing(context, 2),
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${pending.length}',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 발주 탭 (권한이 있는 경우만 표시)
                    if (_hasPurchaseApprovalAuth)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _mainTabController.animateTo(1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.spacing(context, 14),
                            ),
                            decoration: BoxDecoration(
                              color: _mainTabController.index == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 10),
                              ),
                              boxShadow: _mainTabController.index == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: ResponsiveUtils.iconSize(context, 18),
                                  color: _mainTabController.index == 1
                                      ? AppColors.primary
                                      : const Color(0xFF8E8E93),
                                ),
                                SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                Text(
                                  '발주승인',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontSize: 15,
                                    fontWeight: _mainTabController.index == 1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _mainTabController.index == 1
                                        ? const Color(0xFF1C1C1E)
                                        : const Color(0xFF8E8E93),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _mainTabController,
                  children: [
                    // 연차/출장 탭 콘텐츠
                    Column(
                      children: [
                        // 심플한 필터 칩 스타일의 서브 탭
                        Container(
                          height: ResponsiveUtils.spacing(context, 40),
                          margin: EdgeInsets.fromLTRB(
                            ResponsiveUtils.spacing(context, 20),
                            ResponsiveUtils.spacing(context, 0),
                            ResponsiveUtils.spacing(context, 20),
                            ResponsiveUtils.spacing(context, 15),
                          ),
                          child: Row(
                            children: [
                              // 대기중 칩
                              GestureDetector(
                                onTap: () {
                                  _subTabController.animateTo(0);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.spacing(context, 16),
                                    vertical: ResponsiveUtils.spacing(context, 8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: _subTabController.index == 0
                                        ? AppColors.primary
                                        : const Color(0xFFF2F3F5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '대기중',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _subTabController.index == 0
                                              ? Colors.white
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      if (pending.isNotEmpty) ...[
                                        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveUtils.spacing(context, 5),
                                            vertical: ResponsiveUtils.spacing(context, 1),
                                          ),
                                          decoration: BoxDecoration(
                                            color: _subTabController.index == 0
                                                ? Colors.white.withValues(alpha: 0.3)
                                                : const Color(0xFFFF3B30),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${pending.length}',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _subTabController.index == 0
                                                  ? Colors.white
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                              // 처리완료 칩
                              GestureDetector(
                                onTap: () {
                                  _subTabController.animateTo(1);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.spacing(context, 16),
                                    vertical: ResponsiveUtils.spacing(context, 8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: _subTabController.index == 1
                                        ? AppColors.primary
                                        : const Color(0xFFF2F3F5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '처리완료',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _subTabController.index == 1
                                          ? Colors.white
                                          : const Color(0xFF1C1C1E),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 연차/출장 탭 콘텐츠
                        Expanded(
                          child: TabBarView(
                            controller: _subTabController,
                            children: [
                              // 대기중 탭
                              RefreshIndicator(
                                onRefresh: () async {
                                  // 승인 대기 데이터 새로고침
                                  await Provider.of<LeaveProvider>(
                                    context,
                                    listen: false,
                                  ).fetchAllLeaves(forceRefresh: true);
                                },
                                child: pending.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: ResponsiveUtils.iconSize(context, 80),
                                              color: const Color(0xFFE0E0E0),
                                            ),
                                            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                                            Text(
                                              '승인 대기 중인 항목이 없습니다',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF8E8E93),
                                              ),
                                            ),
                                            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                            Text(
                                              '새로운 신청이 들어오면 여기에 표시됩니다',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 14,
                                                color: const Color(0xFFB0B0B0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.spacing(context, 20),
                                          vertical: ResponsiveUtils.spacing(context, 20),
                                        ),
                                        itemCount: pending.length,
                                        itemBuilder: (context, index) {
                                          final l = pending[index];
                                          // superadmin의 연차는 superadmin만 승인 가능
                                          final emp = l['employees'];
                                          final leaveAttendanceRoles = emp is Map
                                              ? (emp['attendance_role'] as List<dynamic>? ?? [])
                                              : [];
                                          final isLeaveSuperAdmin = leaveAttendanceRoles.contains(
                                            'superadmin',
                                          );

                                          // 승인 가능 여부 판단
                                          bool canApprove = false;
                                          if (isLeaveSuperAdmin) {
                                            // superadmin의 연차는 superadmin만 승인 가능
                                            canApprove = isSuperAdmin;
                                          } else {
                                            // 그 외의 경우 기존 규칙 적용
                                            canApprove = hasApprovalRole;
                                          }

                                          return _approvalCard(
                                            context,
                                            l,
                                            provider,
                                            canApprove: canApprove,
                                          );
                                        },
                                      ),
                              ),
                              // 처리완료 탭
                              RefreshIndicator(
                                onRefresh: () async {
                                  // 승인 대기 데이터 새로고침
                                  await Provider.of<LeaveProvider>(
                                    context,
                                    listen: false,
                                  ).fetchAllLeaves(forceRefresh: true);
                                },
                                child: thisMonthDone.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.history,
                                              size: ResponsiveUtils.iconSize(context, 80),
                                              color: const Color(0xFFE0E0E0),
                                            ),
                                            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                                            Text(
                                              '이번 달 처리 완료 내역이 없습니다',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF8E8E93),
                                              ),
                                            ),
                                            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                            Text(
                                              '승인하거나 반려한 항목이 여기에 표시됩니다',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 14,
                                                color: const Color(0xFFB0B0B0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.spacing(context, 20),
                                          vertical: ResponsiveUtils.spacing(context, 20),
                                        ),
                                        itemCount: thisMonthDone.length,
                                        itemBuilder: (context, index) {
                                          return _approvalCard(
                                            context,
                                            thisMonthDone[index],
                                            provider,
                                            showButtons: false,
                                            canApprove: false,
                                            showDeleteButton:
                                                hasApprovalRole, // 승인 권한이 있으면 삭제 버튼 표시
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 발주승인 탭
                    const PurchaseApprovalWidget(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _approvalCard(
    BuildContext context,
    Map<String, dynamic> l,
    LeaveProvider provider, {
    bool showButtons = true,
    bool canApprove = false,
    bool showDeleteButton = false,
  }) {
    final type = l['type'];
    String typeLabel;
    Color typeBgColor;
    Color typeTextColor;
    switch (type) {
      case 'annual':
        typeLabel = '연차';
        typeBgColor = const Color(0xFFE3F2FD);
        typeTextColor = const Color(0xFF1976D2);
        break;
      case 'halfAm':
      case 'half_am':
        typeLabel = '오전반차';
        typeBgColor = const Color(0xFFFFF3E0);
        typeTextColor = const Color(0xFFFF9800);
        break;
      case 'halfPm':
      case 'half_pm':
        typeLabel = '오후반차';
        typeBgColor = const Color(0xFFE8F5E9);
        typeTextColor = const Color(0xFF388E3C);
        break;
      case 'official':
        typeLabel = '공가';
        typeBgColor = const Color(0xFFF5F5F5);
        typeTextColor = const Color(0xFF757575);
        break;
      case 'biztrip':
        typeLabel = '출장';
        typeBgColor = const Color(0xFFF3E5F5);
        typeTextColor = const Color(0xFF7B1FA2);
        break;
      default:
        typeLabel = '연차';
        typeBgColor = const Color(0xFFE3F2FD);
        typeTextColor = const Color(0xFF1976D2);
    }
    final isBiztrip = type == 'biztrip';
    final name = l['name'] ?? l['user_email'] ?? '-';
    final start = DateTime.parse(l['start_date']);
    final end = DateTime.parse(l['end_date']);
    final days = end.difference(start).inDays + 1;

    // 그룹화된 항목 처리
    final int groupedCount = l['grouped_count'] ?? 1;
    String period;
    if (groupedCount > 1) {
      // 그룹화된 항목: "연속 N건" 표시
      period =
          '${DateFormat('yyyy.MM.dd').format(start)} ~ ${DateFormat('yyyy.MM.dd').format(end)} (연속 ${groupedCount}건, $days일)';
    } else {
      period =
          '${DateFormat('yyyy.MM.dd').format(start)} ~ ${DateFormat('yyyy.MM.dd').format(end)} ($days일)';
    }

    final createdAt = DateFormat('yyyy.MM.dd').format(DateTime.parse(l['created_at']));
    final reason = l['reason'] ?? '-';
    final status = l['status'];
    final dest = l['destination'] ?? '';
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 16)),
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 14)),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 이름, 유형, 상태
          Row(
            children: [
              Icon(
                Icons.person,
                color: AppColors.primary,
                size: ResponsiveUtils.iconSize(context, 22),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Expanded(
                child: Text(
                  name,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 10),
                  vertical: ResponsiveUtils.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: typeBgColor,
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                ),
                child: Text(
                  typeLabel,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 14,
                    color: typeTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              _statusChip(status),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 14)),
          // 상세 정보
          _infoRow(Icons.date_range, '기간', period),
          if (isBiztrip && dest.isNotEmpty) _infoRow(Icons.place, '목적지', dest),
          _infoRow(Icons.calendar_today, '신청일', createdAt),
          // 최종 승인자 정보 표시 (처리완료 탭에서만)
          if (!showButtons && status != 'pending') ...[
            if (l['approved_by'] != null && l['approved_by'].isNotEmpty)
              _infoRow(Icons.check_circle, '최종승인', l['approved_by'])
            else if (l['rejected_by'] != null && l['rejected_by'].isNotEmpty)
              _infoRow(Icons.cancel, '반려처리', l['rejected_by']),
          ],
          SizedBox(height: ResponsiveUtils.spacing(context, 14)),
          // 사유
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 14)),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
            ),
            child: Text(
              reason,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 16,
                color: const Color(0xFF6C757D),
              ),
            ),
          ),
          if (showDeleteButton && status != 'pending') ...[
            // 처리완료 항목에 대한 삭제 버튼
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [AppShadows.button],
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                  ),
                ),
                onPressed: () async {
                  final confirmed = await _showConfirmationDialog(
                    context,
                    '삭제 확인',
                    '이 ${typeLabel} 기록을 삭제하시겠습니까?\n삭제 후 복구할 수 없으며, 신청자에게 알림이 전송됩니다.',
                    '삭제',
                    const Color(0xFFFF3B30),
                  );
                  if (confirmed == true) {
                    await _deleteApprovedLeave(l, provider);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  '삭제',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ] else if (showButtons && status == 'pending' && canApprove) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                        ),
                      ),
                      onPressed: () async {
                        final groupedCountMsg = groupedCount > 1 ? ' (연속 ${groupedCount}건)' : '';
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '반려 확인',
                          '$name님의 $typeLabel 신청$groupedCountMsg을 반려하시겠습니까?',
                          '반려',
                          const Color(0xFFFF3B30),
                        );
                        if (confirmed == true) {
                          // 그룹화된 항목이면 모든 ID에 대해 처리 (첫 번째만 알림)
                          final groupedIds = l['grouped_ids'] as List<dynamic>?;
                          if (groupedIds != null && groupedIds.isNotEmpty) {
                            for (int i = 0; i < groupedIds.length; i++) {
                              final isFirstItem = i == 0;
                              await provider.updateLeaveStatus(
                                groupedIds[i],
                                'rejected',
                                skipNotification: !isFirstItem, // 첫 번째만 알림
                              );
                            }
                          } else {
                            await provider.updateLeaveStatus(l['id'], 'rejected');
                          }
                        }
                      },
                      child: Text(
                        '반려',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                        ),
                      ),
                      onPressed: () async {
                        final groupedCountMsg = groupedCount > 1 ? ' (연속 ${groupedCount}건)' : '';
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '승인 확인',
                          '$name님의 $typeLabel 신청$groupedCountMsg을 승인하시겠습니까?',
                          '승인',
                          const Color(0xFF34C759),
                        );
                        if (confirmed == true) {
                          // 그룹화된 항목이면 모든 ID에 대해 처리 (첫 번째만 알림)
                          final groupedIds = l['grouped_ids'] as List<dynamic>?;
                          if (groupedIds != null && groupedIds.isNotEmpty) {
                            for (int i = 0; i < groupedIds.length; i++) {
                              final isFirstItem = i == 0;
                              await provider.updateLeaveStatus(
                                groupedIds[i],
                                'approved',
                                skipNotification: !isFirstItem, // 첫 번째만 알림
                              );
                            }
                          } else {
                            await provider.updateLeaveStatus(l['id'], 'approved');
                          }
                        }
                      },
                      child: Text(
                        '승인',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (showButtons && status == 'pending' && !canApprove) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 12)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info,
                    color: const Color(0xFFFFA726),
                    size: ResponsiveUtils.iconSize(context, 20),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Text(
                    '승인 권한이 없습니다',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      color: const Color(0xFFFFA726),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!showButtons) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 10)),
              decoration: BoxDecoration(
                color: status == 'approved'
                    ? const Color(0xFF34C759).withValues(alpha: 0.12)
                    : const Color(0xFFFF3B30).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              ),
              child: Text(
                status == 'approved' ? '승인 완료' : '반려',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: status == 'approved' ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteApprovedLeave(Map<String, dynamic> leave, LeaveProvider provider) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 그룹화된 항목이면 모든 ID에 대해 처리
      final groupedIds = leave['grouped_ids'] as List<dynamic>?;
      if (groupedIds != null && groupedIds.isNotEmpty) {
        for (final id in groupedIds) {
          await provider.deleteApprovedLeave(
            leaveId: id,
            requesterEmail: leave['user_email'] ?? '',
            requesterName: leave['name'] ?? '',
            leaveType: leave['type'] ?? '',
            startDate: leave['start_date'] ?? '',
            endDate: leave['end_date'] ?? '',
            status: leave['status'] ?? '',
          );
        }
      } else {
        await provider.deleteApprovedLeave(
          leaveId: leave['id'],
          requesterEmail: leave['user_email'] ?? '',
          requesterName: leave['name'] ?? '',
          leaveType: leave['type'] ?? '',
          startDate: leave['start_date'] ?? '',
          endDate: leave['end_date'] ?? '',
          status: leave['status'] ?? '',
        );
      }

      // 로딩 닫기
      if (mounted) Navigator.of(context).pop();

      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제가 완료되었습니다.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) Navigator.of(context).pop();

      // 에러 메시지
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 6)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB0B0B0), size: ResponsiveUtils.iconSize(context, 18)),
          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          Text(
            label,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 14,
              color: const Color(0xFF888888),
            ),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          Expanded(
            child: Text(
              value,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    String label;
    if (status == 'approved') {
      bg = const Color(0xFF34C759).withValues(alpha: 0.12);
      fg = const Color(0xFF34C759);
      label = '승인';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFF3B30).withValues(alpha: 0.12);
      fg = const Color(0xFFFF3B30);
      label = '반려';
    } else {
      bg = const Color(0xFFFFA726).withValues(alpha: 0.12);
      fg = const Color(0xFFFFA726);
      label = '대기';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 10),
        vertical: ResponsiveUtils.spacing(context, 4),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
      ),
      child: Text(
        label,
        style: ResponsiveUtils.getTextStyle(
          context,
          fontSize: 14,
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    String confirmText,
    Color confirmColor,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 14)),
          ),
          title: Text(
            title,
            style: ResponsiveUtils.getTextStyle(context, fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 16,
              color: const Color(0xFF8E8E93),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            ResponsiveUtils.spacing(context, 24),
            ResponsiveUtils.spacing(context, 20),
            ResponsiveUtils.spacing(context, 24),
            ResponsiveUtils.spacing(context, 20),
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            ResponsiveUtils.spacing(context, 24),
            ResponsiveUtils.spacing(context, 0),
            ResponsiveUtils.spacing(context, 24),
            ResponsiveUtils.spacing(context, 24),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F7),
                      foregroundColor: const Color(0xFF1C1C1E),
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      '취소',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      confirmText,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // (불필요) 확인 다이얼로그 내 위젯 렌더 제거
          ],
        );
      },
    );
  }
}
