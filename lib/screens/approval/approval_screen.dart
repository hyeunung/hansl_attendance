import 'dart:async';
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
import '../../widgets/shared/flat_section.dart';
import '../../widgets/purchase/purchase_approval_widget.dart';
import '../../widgets/purchase/purchase_waiting_widget.dart';
import '../../widgets/purchase/receiving_waiting_widget.dart';
import '../../services/badge_cache_service.dart';
import '../../utils/user_role_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/common/notification_banner_widget.dart';

class ApprovalScreen extends StatefulWidget {
  final int? initialMainTab; // 0: 연차/출장, 1: 발주승인, 2: 구매대기, 3: 입고대기
  const ApprovalScreen({super.key, this.initialMainTab});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late TabController _mainTabController; // 메인 탭 (연차/출장, 발주승인, 구매대기, 입고대기)
  late TabController _subTabController; // 서브 탭 (대기중, 처리완료)
  bool _hasPurchaseApprovalAuth = false; // 발주 승인 권한 여부
  bool _hasLeaveApprovalAuth = false; // 연차 승인 권한 여부
  
  // Realtime 구독
  RealtimeChannel? _leaveChannel;
  RealtimeChannel? _purchaseChannel;
  RealtimeChannel? _purchaseItemsChannel;
  bool _isRealtimeRefreshing = false;
  Timer? _realtimeDebounce;
  
  // 배지 카운트 즉시 표시를 위한 로컬 캐시
  Map<String, int> _cachedBadgeCounts = {
    'leave_count': 0,
    'purchase_waiting_count': 0,
    'receiving_waiting_count': 0,
  };

  @override
  void initState() {
    super.initState();
    // 4개 탭으로 설정 (연차/출장, 발주승인, 구매대기, 입고대기)
    int safeInitialIndex = widget.initialMainTab ?? 0;
    if (safeInitialIndex >= 4) {
      safeInitialIndex = 0;
    }
    _mainTabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: safeInitialIndex,
    );
    _subTabController = TabController(length: 2, vsync: this);

    // TabController 리스너 추가 - 탭 변경시 UI 업데이트
    _mainTabController.addListener(() {
      if (mounted) setState(() {});
    });
    _subTabController.addListener(() {
      if (mounted) setState(() {});
    });

    // 로컬 캐시에서 배지 카운트 즉시 로드
    _loadCachedBadgeCounts();
    
    _loadData();
    _setupRealtimeSubscriptions();
  }
  
  // 로컬 캐시에서 배지 카운트 즉시 로드
  void _loadCachedBadgeCounts() {
    BadgeCacheService.loadCachedBadgeCounts().then((cachedCounts) {
      if (mounted) {
        setState(() {
          _cachedBadgeCounts = cachedCounts;
        });
      }
    }).catchError((e) {
      // 캐시 로드 실패해도 무시
    });
  }
  
  // 현재 배지 카운트를 로컬에 저장
  void _saveBadgeCounts() {
    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      BadgeCacheService.saveBadgeCounts(
        leaveCount: leaveProvider.allPendingCount,
        purchaseWaitingCount: purchaseProvider.purchaseWaitingCount,
        receivingWaitingCount: purchaseProvider.receivingWaitingCount,
      );
      
      // 메모리 캐시도 업데이트
      setState(() {
        _cachedBadgeCounts = {
          'leave_count': leaveProvider.allPendingCount,
          'purchase_waiting_count': purchaseProvider.purchaseWaitingCount,
          'receiving_waiting_count': purchaseProvider.receivingWaitingCount,
        };
      });
    } catch (e) {
      // 저장 실패해도 무시
    }
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
        final leaveProvider = Provider.of<LeaveProvider>(
          context,
          listen: false,
        );
        final purchaseProvider = Provider.of<PurchaseProvider>(
          context,
          listen: false,
        );
        final userProvider = Provider.of<UserProvider>(context, listen: false);


        // 연차 데이터 비동기 로드 (await 제거로 UI 즉시 렌더링)
        leaveProvider
            .fetchAllLeaves(forceRefresh: true)
            .then((_) {
              // 배지 카운트 저장
              _saveBadgeCounts();
            })
            .catchError((e) {
            });

        // 발주 데이터 비동기 로드 (모든 역할에서 필요 - 구매대기/입고대기 표시를 위해)
        // app_admin, lead buyer, 발주승인권한자, 일반직원 모두 각자 볼 수 있는 데이터가 필요
        purchaseProvider
            .fetchPendingPurchases(employee: userProvider.employee)
            .then((_) {
              // 배지 카운트 저장
              _saveBadgeCounts();
            })
            .catchError((e) {
            });
      }
    });
  }

  // 실시간 구독 설정 (연차/발주)
  void _setupRealtimeSubscriptions() {
    final client = Supabase.instance.client;

    _leaveChannel = client
        .channel('approval_leave_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leave',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .subscribe();

    _purchaseChannel = client
        .channel('approval_purchase_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_requests',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .subscribe();

    _purchaseItemsChannel = client
        .channel('approval_purchase_items_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_request_items',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .subscribe();

    // business_trips 변경 감지
    client
        .channel('approval_business_trips_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'business_trips',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .subscribe();
  }

  // 실시간 이벤트 수신 시 데이터 리프레시 (단순 재조회로 일관성 유지)
  void _handleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_isRealtimeRefreshing) return;
      _isRealtimeRefreshing = true;

      // 짧은 시간에 여러 이벤트가 와도 한 번만 재조회
      Future.microtask(() async {
        try {
          if (!mounted) return;

          final leaveProvider = Provider.of<LeaveProvider>(
            context,
            listen: false,
          );
          final purchaseProvider = Provider.of<PurchaseProvider>(
            context,
            listen: false,
          );
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );

          await leaveProvider.fetchAllLeaves(forceRefresh: true);
          await purchaseProvider.fetchPendingPurchases(
            employee: userProvider.employee,
          );
          await purchaseProvider.fetchCompletedPurchases(
            employee: userProvider.employee,
          );

          // 배지 캐시도 최신 상태로 동기화
          _saveBadgeCounts();
        } catch (_) {
          // 무시: 실시간 콜백에서 예외로 인한 크래시 방지
        } finally {
          _isRealtimeRefreshing = false;
        }
      });
    });
  }

  @override
  void dispose() {
    if (_leaveChannel != null) {
      Supabase.instance.client.removeChannel(_leaveChannel!);
      _leaveChannel = null;
    }
    if (_purchaseChannel != null) {
      Supabase.instance.client.removeChannel(_purchaseChannel!);
      _purchaseChannel = null;
    }
    if (_purchaseItemsChannel != null) {
      Supabase.instance.client.removeChannel(_purchaseItemsChannel!);
      _purchaseItemsChannel = null;
    }
    _realtimeDebounce?.cancel();
    _mainTabController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final attendanceRoles =
        employee?['attendance_role'] as List<dynamic>? ?? [];
    final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];

    // purchase_role에 따른 발주 승인 권한 확인

    final bool hasPurchaseApproval =
        purchaseRoles.contains('middle_manager') ||
        purchaseRoles.contains('final_approver') ||
        purchaseRoles.contains('raw_material_manager') ||
        purchaseRoles.contains('consumable_manager') ||
        purchaseRoles.contains('app_admin');


    // 탭 개수 조정 (초기화 시점과 다른 경우)
    if (_hasPurchaseApprovalAuth != hasPurchaseApproval) {
      _hasPurchaseApprovalAuth = hasPurchaseApproval;
      // 항상 4개 탭 유지 (연차/출장, 발주승인, 구매대기, 입고대기)
      const tabCount = 4;


      // TabController 재생성 필요
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _mainTabController.dispose();
            // initialMainTab을 고려하여 TabController 재생성
            int targetIndex = widget.initialMainTab ?? 0;
            // 발주 권한이 없는데 발주 탭(1)을 요청한 경우 0으로
            if (!hasPurchaseApproval && targetIndex > 0) {
              targetIndex = 0;
            }
            // 인덱스가 탭 개수를 초과하는 경우 방지
            if (targetIndex >= tabCount) {
              targetIndex = 0;
            }
            _mainTabController = TabController(
              length: tabCount,
              vsync: this,
              initialIndex: targetIndex,
            );
            _mainTabController.addListener(() {
              if (mounted) setState(() {});
            });
          });
          // 발주 데이터 로드 (setState 밖에서 실행)
          if (hasPurchaseApproval) {
            final purchaseProvider = Provider.of<PurchaseProvider>(
              context,
              listen: false,
            );
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
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
    final bool isCadManager = attendanceRoles.contains(
      'CAD_manager',
    ); // 대문자로 수정!
    final bool isDevManager = attendanceRoles.contains('개발팀_manager');
    final bool isSupportManager = attendanceRoles.contains('경영지원팀_manager');
    final bool isLabManager = attendanceRoles.contains('연구소_manager');
    final bool isManager =
        isDev3Manager ||
        isCadManager ||
        isDevManager ||
        isSupportManager ||
        isLabManager;
    final bool hasApprovalRole = isAdminOrSuper || isManager;
    
    // 연차 승인 권한 업데이트
    _hasLeaveApprovalAuth = hasApprovalRole;

    // attendance_role에 따른 승인 가능 부서 매핑
    final List<String> approvalDepartments = [];
    if (isAdminOrSuper) {
      // admin/superadmin은 모든 부서 승인 가능
      approvalDepartments.addAll([
        '개발1팀',
        '개발2팀',
        '개발3팀',
        'CAD',
        '경영지원팀',
        '연구소',
        '개발팀',
      ]);
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
    // UserRoleHelper 사용하여 역할 체크
    final bool isAppAdmin = UserRoleHelper.isAppAdmin(purchaseRoles);
    final bool isPureLeadBuyer = UserRoleHelper.isPureLeadBuyer(purchaseRoles);
    final bool isRegularEmployee = UserRoleHelper.isRegularEmployee(purchaseRoles) && !hasApprovalRole;
    
    // PurchaseProvider 가져오기 (일반 직원의 입고대기 개수 표시를 위해)
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    
    // 타이틀 결정 (app_admin 최우선, 일반 직원의 경우 입고대기 개수 포함)
    String appBarTitle = '승인 관리';
    if (isAppAdmin) {
      // app_admin은 항상 '승인 관리'
      appBarTitle = '승인 관리';
    } else if (isRegularEmployee) {
      // 일반 직원은 입고대기 개수를 제목에 표시
      final receivingCount = purchaseProvider.receivingWaitingCount;
      appBarTitle = receivingCount > 0 ? '입고대기 ($receivingCount)' : '입고대기';
    } else if (isPureLeadBuyer) {
      appBarTitle = '구매/입고 대기';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/icon_40.png', width: 34, height: 34),
            SizedBox(width: ResponsiveUtils.spacing(context, 8)),
            Text(appBarTitle, style: AppTextStyles.appBarTitle(context)),
            if (isAdminOrSuper) ...[
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 8),
                  vertical: ResponsiveUtils.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 12),
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                      size: ResponsiveUtils.iconSize(context, 16),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                    Text(
                      'ADMIN',
                      style: AppTextStyles.chipSmall(context).copyWith(
                        color: AppColors.primary,
                        fontSize: 12,
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: const [],
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          List<Map<String, dynamic>> allLeaves = provider.allLeaves;


          // attendance_role에 따른 필터링
          if (hasApprovalRole) {

            if (attendanceRoles.contains('superadmin')) {
              // SuperAdmin: 모든 직원의 신청 표시 (필터링 없음)
            } else if (attendanceRoles.contains('admin')) {
              // Admin: superadmin을 제외한 모든 신청 표시
              allLeaves = allLeaves.where((l) {
                final emp = l['employees'];
                final leaveAttendanceRoles = emp is Map
                    ? (emp['attendance_role'] as List<dynamic>? ?? [])
                    : [];
                return !leaveAttendanceRoles.contains('superadmin');
              }).toList();
            } else if (isManager) {
              // Manager: 해당 부서의 일반 직원만 표시 (매니저 제외, 자신 포함)
              allLeaves = allLeaves.where((l) {
                final emp = l['employees'];
                final leaveDept = emp is Map ? emp['department'] : null;
                final leaveEmail = l['user_email'] ?? '';
                final leaveAttendanceRoles = emp is Map
                    ? (emp['attendance_role'] as List<dynamic>? ?? [])
                    : [];


                // 자신의 연차는 제외 (스스로 승인 불가)
                if (leaveEmail == userProvider.email) {
                  return false;
                }

                // superadmin의 연차는 제외 (부서 매니저가 승인 불가)
                if (leaveAttendanceRoles.contains('superadmin')) {
                  return false;
                }

                // admin의 연차도 제외 (부서 매니저가 승인 불가)
                if (leaveAttendanceRoles.contains('admin')) {
                  return false;
                }

                // 다른 매니저의 연차는 제외 (매니저끼리 승인 불가)
                final hasManagerRole = managerRoles.any(
                  (role) => leaveAttendanceRoles.contains(role),
                );
                if (hasManagerRole) {
                  return false;
                }

                // 해당 부서 일반 직원만 표시
                final shouldShow =
                    leaveDept != null &&
                    approvalDepartments.contains(leaveDept);
                return shouldShow;
              }).toList();
            }
          } else {
            // 승인 권한이 없으면 비워서 표시
            allLeaves = [];
          }

          final pending = allLeaves
              .where((l) => l['status'] == 'pending')
              .toList();

          // 발주승인 탭 뱃지 계산
          int pendingApprovalCount = 0;
          if (_hasPurchaseApprovalAuth) {
            // PurchaseProvider에서 대기 중인 발주 데이터 가져오기
            final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
            final pendingOrders = purchaseProvider.pendingOrders;
            
            // 권한에 따른 필터링
            if (purchaseRoles.contains('app_admin') || purchaseRoles.contains('lead buyer')) {
              // app_admin, lead buyer: 모든 대기 발주
              pendingApprovalCount = pendingOrders.length;
            } else {
              // 기타 권한: 본인이 신청한 발주만
              final currentEmployeeName = userProvider.employee?['name'];
              pendingApprovalCount = pendingOrders
                  .where((group) => group.requesterName == currentEmployeeName)
                  .length;
            }
            
          }



          // Admin/SuperAdmin은 전체 직원의 처리완료 건을 보여줌
          List<Map<String, dynamic>> done;
          if (isAdminOrSuper) {
            // Admin/SuperAdmin: 전체 직원의 처리완료 건을 보여줌
            done = provider.allLeaves
                .where((l) => l['status'] != 'pending')
                .toList();
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
            return date.year == thisYear &&
                date.month == thisMonth &&
                l['status'] != 'pending';
          }).toList();

          return Column(
            children: [
              // 일반 직원은 탭 표시 안 함 (입고대기만 표시)
              if (!isRegularEmployee) // 일반 직원이 아닌 경우만 탭 표시
                // 통합된 탭 디자인 - Segmented Control 스타일
                Container(
                  margin: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 4)),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 연차/출장 탭 (attendance_role 권한이 있는 경우만 표시)
                      if (_hasLeaveApprovalAuth)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _mainTabController.animateTo(0);
                          },
                          child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 16),
                          ),
                          decoration: BoxDecoration(
                            color: _mainTabController.index == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 10),
                            ),
                            boxShadow: _mainTabController.index == 0
                                ? AppShadows.smShadow
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: ResponsiveUtils.iconSize(context, 26),
                                    color: _mainTabController.index == 0
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                  ),
                                  if (pending.isNotEmpty)
                                    Positioned(
                                      right: -8,
                                      top: -4,
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          ResponsiveUtils.spacing(context, 2),
                                        ),
                                        constraints: BoxConstraints(
                                          minWidth: ResponsiveUtils.spacing(context, 18),
                                          minHeight: ResponsiveUtils.spacing(context, 18),
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(
                                            ResponsiveUtils.spacing(context, 8),
                                          ),
                                          border: Border.all(
                                            color: _mainTabController.index == 0
                                                ? Colors.white
                                                : AppColors.backgroundSecondary,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${pending.isNotEmpty ? pending.length : (_cachedBadgeCounts['leave_count'] ?? 0)}',
                                            style: AppTextStyles.compactLabel(context).copyWith(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 6),
                              ),
                              Text(
                                '연차/출장',
                                style: AppTextStyles.inputLabel(context).copyWith(
                                  fontWeight: _mainTabController.index == 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _mainTabController.index == 0
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 발주승인 탭 (권한이 있는 경우만 표시)
                    if (_hasPurchaseApprovalAuth)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _mainTabController.animateTo(1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.spacing(context, 16),
                            ),
                            decoration: BoxDecoration(
                              color: _mainTabController.index == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 10),
                              ),
                              boxShadow: _mainTabController.index == 1
                                  ? AppShadows.smShadow
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: ResponsiveUtils.iconSize(context, 26),
                                      color: _mainTabController.index == 1
                                          ? AppColors.primary
                                          : AppColors.textTertiary,
                                    ),
                                    if (pendingApprovalCount > 0)
                                      Positioned(
                                        right: -8,
                                        top: -4,
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            ResponsiveUtils.spacing(context, 2),
                                          ),
                                          constraints: BoxConstraints(
                                            minWidth: ResponsiveUtils.spacing(context, 18),
                                            minHeight: ResponsiveUtils.spacing(context, 18),
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveUtils.spacing(context, 8),
                                            ),
                                            border: Border.all(
                                              color: _mainTabController.index == 1
                                                  ? Colors.white
                                                  : AppColors.backgroundSecondary,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$pendingApprovalCount',
                                              style: AppTextStyles.compactLabel(context).copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(
                                  height: ResponsiveUtils.spacing(context, 6),
                                ),
                                Text(
                                  '발주승인',
                                  style: AppTextStyles.inputLabel(context).copyWith(
                                    fontWeight: _mainTabController.index == 1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _mainTabController.index == 1
                                        ? AppColors.textPrimary
                                        : AppColors.textTertiary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 구매대기 탭 (lead buyer와 app_admin만 표시)
                    if (isAppAdmin || isPureLeadBuyer)
                      Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _mainTabController.animateTo(2);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 16),
                          ),
                          decoration: BoxDecoration(
                            color: _mainTabController.index == 2
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 10),
                            ),
                            boxShadow: _mainTabController.index == 2
                                ? AppShadows.smShadow
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: ResponsiveUtils.iconSize(context, 26),
                                    color: _mainTabController.index == 2
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                  ),
                                  // 구매대기 배지 - 로컬 캐시 + Provider 조합으로 즉시 표시
                                  Consumer<PurchaseProvider>(
                                    builder: (context, purchaseProvider, _) {
                                      final providerCount = purchaseProvider.purchaseWaitingCount;
                                      final cachedCount = _cachedBadgeCounts['purchase_waiting_count'] ?? 0;
                                      final count = providerCount > 0 ? providerCount : cachedCount;
                                      if (count > 0) {
                                        return Positioned(
                                          right: -8,
                                          top: -4,
                                          child: Container(
                                            padding: EdgeInsets.all(
                                              ResponsiveUtils.spacing(context, 2),
                                            ),
                                            constraints: BoxConstraints(
                                              minWidth: ResponsiveUtils.spacing(context, 18),
                                              minHeight: ResponsiveUtils.spacing(context, 18),
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              borderRadius: BorderRadius.circular(
                                                ResponsiveUtils.spacing(context, 8),
                                              ),
                                              border: Border.all(
                                                color: _mainTabController.index == 2
                                                    ? Colors.white
                                                    : AppColors.backgroundSecondary,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$count',
                                                style: AppTextStyles.compactLabel(context).copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 6),
                              ),
                              Text(
                                '구매대기',
                                style: AppTextStyles.inputLabel(context).copyWith(
                                  fontWeight: _mainTabController.index == 2
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _mainTabController.index == 2
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 입고대기 탭 (일반 직원 제외한 모든 역할에서 표시)
                    if (!isRegularEmployee)
                      Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _mainTabController.animateTo(3);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 16),
                          ),
                          decoration: BoxDecoration(
                            color: _mainTabController.index == 3
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 10),
                            ),
                            boxShadow: _mainTabController.index == 3
                                ? AppShadows.smShadow
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: ResponsiveUtils.iconSize(context, 26),
                                    color: _mainTabController.index == 3
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                  ),
                                  // 입고대기 배지 - 로컬 캐시 + Provider 조합으로 즉시 표시
                                  Consumer<PurchaseProvider>(
                                    builder: (context, purchaseProvider, _) {
                                      final providerCount = purchaseProvider.receivingWaitingCount;
                                      final cachedCount = _cachedBadgeCounts['receiving_waiting_count'] ?? 0;
                                      final count = providerCount > 0 ? providerCount : cachedCount;
                                      if (count > 0) {
                                        return Positioned(
                                          right: -8,
                                          top: -4,
                                          child: Container(
                                            padding: EdgeInsets.all(
                                              ResponsiveUtils.spacing(context, 2),
                                            ),
                                            constraints: BoxConstraints(
                                              minWidth: ResponsiveUtils.spacing(context, 18),
                                              minHeight: ResponsiveUtils.spacing(context, 18),
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              borderRadius: BorderRadius.circular(
                                                ResponsiveUtils.spacing(context, 8),
                                              ),
                                              border: Border.all(
                                                color: _mainTabController.index == 3
                                                    ? Colors.white
                                                    : AppColors.backgroundSecondary,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$count',
                                                style: AppTextStyles.compactLabel(context).copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 6),
                              ),
                              Text(
                                '입고대기',
                                style: AppTextStyles.inputLabel(context).copyWith(
                                  fontWeight: _mainTabController.index == 3
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _mainTabController.index == 3
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                child: isRegularEmployee 
                  ? Padding(
                      padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 15)),
                      child: const ReceivingWaitingWidget(),
                    ) // 일반 직원은 입고대기만 표시 (상단 여백 추가)
                  : TabBarView(
                      controller: _mainTabController,
                      children: [
                        // 연차/출장 탭 콘텐츠 (권한이 있는 경우만 표시)
                        _hasLeaveApprovalAuth
                          ? Column(
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
                                    horizontal: ResponsiveUtils.spacing(
                                      context,
                                      16,
                                    ),
                                    vertical: ResponsiveUtils.spacing(
                                      context,
                                      8,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: _subTabController.index == 0
                                        ? AppColors.primary
                                        : AppColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '대기중',
                                        style: AppTextStyles.inputLabel(context).copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: _subTabController.index == 0
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (pending.isNotEmpty) ...[
                                        SizedBox(
                                          width: ResponsiveUtils.spacing(
                                            context,
                                            6,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveUtils.spacing(
                                              context,
                                              5,
                                            ),
                                            vertical: ResponsiveUtils.spacing(
                                              context,
                                              1,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color: _subTabController.index == 0
                                                ? Colors.white.withValues(
                                                    alpha: 0.3,
                                                  )
                                                : AppColors.error,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${pending.length}',
                                            style: AppTextStyles.chipSmall(context).copyWith(
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
                              SizedBox(
                                width: ResponsiveUtils.spacing(context, 10),
                              ),
                              // 처리완료 칩
                              GestureDetector(
                                onTap: () {
                                  _subTabController.animateTo(1);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.spacing(
                                      context,
                                      16,
                                    ),
                                    vertical: ResponsiveUtils.spacing(
                                      context,
                                      8,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: _subTabController.index == 1
                                        ? AppColors.primary
                                        : AppColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '처리완료',
                                    style: AppTextStyles.inputLabel(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _subTabController.index == 1
                                          ? Colors.white
                                          : AppColors.textPrimary,
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
                                  if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                                },
                                child: pending.isEmpty
                                    ? ListView(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.spacing(context, 20),
                                          vertical: ResponsiveUtils.spacing(context, 20),
                                        ),
                                        children: [
                                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                          Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  size: ResponsiveUtils.iconSize(
                                                    context,
                                                    80,
                                                  ),
                                                  color: AppColors.border,
                                                ),
                                                SizedBox(
                                                  height: ResponsiveUtils.spacing(
                                                    context,
                                                    20,
                                                  ),
                                                ),
                                                Text(
                                                  '승인 대기 중인 항목이 없습니다',
                                                  style: AppTextStyles.cardTitle(context).copyWith(
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: ResponsiveUtils.spacing(
                                                    context,
                                                    8,
                                                  ),
                                                ),
                                                Text(
                                                  '새로운 신청이 들어오면 여기에 표시됩니다',
                                                  style: AppTextStyles.emptyState(context),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.spacing(
                                            context,
                                            20,
                                          ),
                                          vertical: ResponsiveUtils.spacing(
                                            context,
                                            20,
                                          ),
                                        ),
                                        itemCount: pending.length,
                                        itemBuilder: (context, index) {
                                          final l = pending[index];
                                          // superadmin의 연차는 superadmin만 승인 가능
                                          final emp = l['employees'];
                                          final leaveAttendanceRoles =
                                              emp is Map
                                              ? (emp['attendance_role']
                                                        as List<dynamic>? ??
                                                    [])
                                              : [];
                                          final isLeaveSuperAdmin =
                                              leaveAttendanceRoles.contains(
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
                                  if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                                },
                                child: thisMonthDone.isEmpty
                                    ? ListView(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.spacing(context, 20),
                                          vertical: ResponsiveUtils.spacing(context, 20),
                                        ),
                                        children: [
                                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                          Center(
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.history,
                                                  size: ResponsiveUtils.iconSize(
                                                    context,
                                                    80,
                                                  ),
                                                  color: AppColors.border,
                                                ),
                                                SizedBox(
                                                  height: ResponsiveUtils.spacing(
                                                    context,
                                                    20,
                                                  ),
                                                ),
                                                Text(
                                                  '이번 달 처리 완료 내역이 없습니다',
                                                  style: AppTextStyles.cardTitle(context).copyWith(
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: ResponsiveUtils.spacing(
                                                    context,
                                                    8,
                                                  ),
                                                ),
                                                Text(
                                                  '승인하거나 반려한 항목이 여기에 표시됩니다',
                                                  style: AppTextStyles.emptyState(context),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.spacing(
                                            context,
                                            20,
                                          ),
                                          vertical: ResponsiveUtils.spacing(
                                            context,
                                            20,
                                          ),
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
                    )
                      : const SizedBox.shrink(), // 권한 없으면 빈 공간
                    // 발주승인 탭 (권한이 있는 경우만 표시)
                    _hasPurchaseApprovalAuth
                      ? const PurchaseApprovalWidget()
                      : const SizedBox.shrink(), // 권한 없으면 빈 공간
                        // 구매대기 탭
                        const PurchaseWaitingWidget(),
                        // 입고대기 탭
                        const ReceivingWaitingWidget(),
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
    Color typeTextColor;
    switch (type) {
      case 'annual':
        typeLabel = '연차';
        typeTextColor = AppColors.biztrip;
        break;
      case 'halfAm':
      case 'half_am':
        typeLabel = '오전반차';
        typeTextColor = AppColors.warning;
        break;
      case 'halfPm':
      case 'half_pm':
        typeLabel = '오후반차';
        typeTextColor = AppColors.success;
        break;
      case 'official':
        typeLabel = '공가';
        typeTextColor = AppColors.gray600;
        break;
      case 'biztrip':
        typeLabel = '출장';
        typeTextColor = AppColors.purple;
        break;
      default:
        typeLabel = '연차';
        typeTextColor = AppColors.biztrip;
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
          '${DateFormat('yyyy.MM.dd').format(start)} ~ ${DateFormat('yyyy.MM.dd').format(end)} (연속 $groupedCount건, $days일)';
    } else {
      period =
          '${DateFormat('yyyy.MM.dd').format(start)} ~ ${DateFormat('yyyy.MM.dd').format(end)} ($days일)';
    }

    final createdAt = DateFormat(
      'yyyy.MM.dd',
    ).format(DateTime.parse(l['created_at']));
    final reason = l['reason'] ?? '-';
    final status = l['status'];
    // 출장 필드 (신규 컬럼 우선, 과거 데이터 호환용 fallback 포함)
    final place = (l['place'] ?? l['destination'] ?? '').toString();
    final transport = (l['transport'] ?? '').toString();
    final travelersList =
        (l['출장자'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final travelersText = travelersList.where((e) => e.trim().isNotEmpty).join(', ');
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
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
                  style: AppTextStyles.cardTitle(context),
                ),
              ),
              StatusChip(label: typeLabel, color: typeTextColor),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              _statusChip(status),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 14)),
          // 상세 정보
          _infoRow(Icons.date_range, '기간', period),
          if (isBiztrip && travelersText.isNotEmpty)
            _infoRow(Icons.group, '출장자', travelersText),
          if (isBiztrip && place.isNotEmpty) _infoRow(Icons.place, '목적지', place),
          if (isBiztrip && transport.isNotEmpty)
            _infoRow(Icons.directions_car, '교통수단', transport),
          _infoRow(Icons.calendar_today, '신청일', createdAt),
          // 최종 승인자 정보 표시 (처리완료 탭에서만 + superadmin만)
          if (!showButtons && status != 'pending') ...[
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                final attendanceRoles = userProvider.employee?['attendance_role'] as List<dynamic>? ?? [];
                if (UserRoleHelper.isSuperAdmin(attendanceRoles)) {
                  return Column(
                    children: [
                      if (l['approved_by'] != null && l['approved_by'].isNotEmpty)
                        _infoRow(Icons.check_circle, '최종승인', l['approved_by'])
                      else if (l['rejected_by'] != null && l['rejected_by'].isNotEmpty)
                        _infoRow(Icons.cancel, '반려처리', l['rejected_by']),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          SizedBox(height: ResponsiveUtils.spacing(context, 14)),
          // 사유
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 14)),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 10),
              ),
            ),
            child: Text(
              reason,
              style: AppTextStyles.cardBody(context),
            ),
          ),
          if (showDeleteButton && status != 'pending') ...[
            // 처리완료 항목에 대한 수정/삭제 버튼
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Row(
              children: [
                // 수정 버튼
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 8),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await _showEditDialog(context, l, provider);
                        } catch (e) {
                          if (context.mounted) {
                            AppBanner.show(context, '수정 화면을 열 수 없습니다: $e', type: BannerType.error);
                          }
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: Text(
                        '수정',
                        style: AppTextStyles.sectionSubtitle(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                // 삭제 버튼
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 8),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '삭제 확인',
                          '이 $typeLabel 기록을 삭제하시겠습니까?\n삭제 후 복구할 수 없으며, 신청자에게 알림이 전송됩니다.',
                          '삭제',
                          AppColors.error,
                        );
                        if (confirmed == true) {
                          await _deleteApprovedLeave(l, provider);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        '삭제',
                        style: AppTextStyles.sectionSubtitle(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (showButtons && status == 'pending' && canApprove) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 8),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        final groupedCountMsg = groupedCount > 1
                            ? ' (연속 $groupedCount건)'
                            : '';
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '반려 확인',
                          '$name님의 $typeLabel 신청$groupedCountMsg을 반려하시겠습니까?',
                          '반려',
                          AppColors.error,
                        );
                        if (confirmed == true) {
                          if (l['is_business_trip'] == true) {
                            // business_trips 테이블 반려
                            await provider.updateBusinessTripStatus(
                              l['business_trip_id'] ?? l['id'],
                              'rejected',
                            );
                          } else {
                            // 그룹화된 항목이면 모든 ID에 대해 처리 (첫 번째만 알림)
                            final groupedIds = l['grouped_ids'] as List<dynamic>?;
                            if (groupedIds != null && groupedIds.isNotEmpty) {
                              for (int i = 0; i < groupedIds.length; i++) {
                                final isFirstItem = i == 0;
                                await provider.updateLeaveStatus(
                                  groupedIds[i],
                                  'rejected',
                                  skipNotification: !isFirstItem,
                                );
                              }
                            } else {
                              await provider.updateLeaveStatus(
                                l['id'],
                                'rejected',
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        '반려',
                        style: AppTextStyles.buttonPrimary(context),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 8),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        final groupedCountMsg = groupedCount > 1
                            ? ' (연속 $groupedCount건)'
                            : '';
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '승인 확인',
                          '$name님의 $typeLabel 신청$groupedCountMsg을 승인하시겠습니까?',
                          '승인',
                          AppColors.success,
                        );
                        if (confirmed == true) {
                          if (l['is_business_trip'] == true) {
                            // business_trips 테이블 승인
                            await provider.updateBusinessTripStatus(
                              l['business_trip_id'] ?? l['id'],
                              'approved',
                            );
                          } else {
                            // 그룹화된 항목이면 모든 ID에 대해 처리 (첫 번째만 알림)
                            final groupedIds = l['grouped_ids'] as List<dynamic>?;
                            if (groupedIds != null && groupedIds.isNotEmpty) {
                              for (int i = 0; i < groupedIds.length; i++) {
                                final isFirstItem = i == 0;
                                await provider.updateLeaveStatus(
                                  groupedIds[i],
                                  'approved',
                                  skipNotification: !isFirstItem,
                                );
                              }
                            } else {
                              await provider.updateLeaveStatus(
                                l['id'],
                                'approved',
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        '승인',
                        style: AppTextStyles.buttonPrimary(context),
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
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.spacing(context, 12),
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.spacing(context, 8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info,
                    color: AppColors.warning,
                    size: ResponsiveUtils.iconSize(context, 20),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Text(
                    '승인 권한이 없습니다',
                    style: AppTextStyles.sectionSubtitle(context).copyWith(
                      color: AppColors.warning,
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
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.spacing(context, 10),
              ),
              decoration: BoxDecoration(
                color: status == 'approved'
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.spacing(context, 8),
                ),
              ),
              child: Text(
                status == 'approved' ? '승인 완료' : '반려',
                style: AppTextStyles.cardTitle(context).copyWith(
                  color: status == 'approved'
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteApprovedLeave(
    Map<String, dynamic> leave,
    LeaveProvider provider,
  ) async {
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
        AppBanner.show(context, '삭제가 완료되었습니다.', type: BannerType.success);
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) Navigator.of(context).pop();

      // 에러 메시지
      if (mounted) {
        AppBanner.show(context, '삭제 중 오류가 발생했습니다: $e', type: BannerType.error);
      }
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 6)),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textDisabled,
            size: ResponsiveUtils.iconSize(context, 18),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          Text(
            label,
            style: AppTextStyles.tableCellSub(context).copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.tableCellSub(context).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color fg;
    String label;
    if (status == 'approved') {
      fg = AppColors.success;
      label = '승인';
    } else if (status == 'rejected') {
      fg = AppColors.error;
      label = '반려';
    } else {
      fg = AppColors.warning;
      label = '대기';
    }
    return StatusChip(label: label, color: fg);
  }

  // 수정 다이얼로그
  Future<void> _showEditDialog(
    BuildContext context,
    Map<String, dynamic> leave,
    LeaveProvider provider,
  ) async {
    
    final startDateController = TextEditingController(
      text: leave['start_date'] ?? '',
    );
    final endDateController = TextEditingController(
      text: leave['end_date'] ?? '',
    );
    final reasonController = TextEditingController(
      text: leave['reason'] ?? '',
    );
    
    String selectedType = leave['type'] ?? 'annual';
    DateTime? selectedStartDate = leave['start_date'] != null
        ? DateTime.parse(leave['start_date'])
        : null;
    DateTime? selectedEndDate = leave['end_date'] != null
        ? DateTime.parse(leave['end_date'])
        : null;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_calendar,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '휴가 정보 수정',
                              style: AppTextStyles.sectionTitle(context),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.textTertiary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    
                    // 컨텐츠
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 신청자 정보
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.infoLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha:0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha:0.1),
                                    child: Text(
                                      (leave['name'] ?? '?')[0],
                                      style: AppTextStyles.sectionSubtitle(context).copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '신청자: ${leave['name'] ?? '알 수 없음'}',
                                        style: AppTextStyles.sectionSubtitle(context).copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '신청일: ${leave['created_at']?.substring(0, 10) ?? ''}',
                                        style: AppTextStyles.inputLabel(context).copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // 휴가 유형
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '휴가 유형',
                                  style: AppTextStyles.sectionSubtitle(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedType,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'annual',
                                      child: Text('연차'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'biztrip',
                                      child: Text('출장'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'half_am',
                                      child: Text('오전 반차'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'half_pm',
                                      child: Text('오후 반차'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'official',
                                      child: Text('공가'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedType = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // 날짜 선택
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '휴가 기간',
                                  style: AppTextStyles.sectionSubtitle(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: selectedStartDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          selectedStartDate = date;
                                          startDateController.text = 
                                              DateFormat('yyyy-MM-dd').format(date);
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundSecondary,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              startDateController.text.isEmpty
                                                  ? '시작일'
                                                  : startDateController.text,
                                              style: AppTextStyles.inputLabel(context).copyWith(
                                                color: startDateController.text.isEmpty
                                                    ? AppColors.gray400
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: selectedEndDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          selectedEndDate = date;
                                          endDateController.text = 
                                              DateFormat('yyyy-MM-dd').format(date);
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundSecondary,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              endDateController.text.isEmpty
                                                  ? '종료일'
                                                  : endDateController.text,
                                              style: AppTextStyles.inputLabel(context).copyWith(
                                                color: endDateController.text.isEmpty
                                                    ? AppColors.gray400
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // 사유
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '사유',
                                  style: AppTextStyles.sectionSubtitle(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: reasonController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: '휴가 사유를 입력하세요',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 버튼 영역
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.gray700,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: AppColors.gray300),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                '취소',
                                style: AppTextStyles.sectionSubtitle(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withValues(alpha:0.8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha:0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  
                                  // 수정 로직 구현
                                  if (selectedStartDate == null || selectedEndDate == null) {
                                    AppBanner.show(context, '시작일과 종료일을 선택해주세요', type: BannerType.error);
                                    return;
                                  }

                                  if (reasonController.text.trim().isEmpty) {
                                    AppBanner.show(context, '사유를 입력해주세요', type: BannerType.error);
                                    return;
                                  }
                                  
                                  
                                  // BuildContext를 먼저 저장
                                  final navigatorContext = Navigator.of(context);
                                  final savedContext = context;
                                  
                                  // 수정 다이얼로그 닫기
                                  Navigator.pop(context);
                                  
                                  // mounted 체크
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  
                                  // 로딩 표시 - GlobalKey 사용
                                  late BuildContext loadingContext;
                                  showDialog(
                                    context: navigatorContext.context,
                                    barrierDismissible: false,
                                    builder: (dialogContext) {
                                      loadingContext = dialogContext;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                  );
                                  
                                  try {
                                    // 실제 수정 로직 호출
                                    await provider.updateLeaveDetails(
                                      leaveId: leave['id'],
                                      type: selectedType,
                                      startDate: DateFormat('yyyy-MM-dd').format(selectedStartDate!),
                                      endDate: DateFormat('yyyy-MM-dd').format(selectedEndDate!),
                                      reason: reasonController.text.trim(),
                                    );
                                    
                                    
                                    // 로딩 닫기 - loadingContext 사용
                                    if (loadingContext.mounted) {
                                      Navigator.of(loadingContext).pop();
                                    } else {
                                      // 백업 방법 - navigatorContext 사용
                                      try {
                                        navigatorContext.pop();
                                      } catch (e) {
                                      }
                                    }
                                    
                                    // 성공 메시지
                                    AppBanner.show(savedContext, '휴가 정보가 수정되었습니다', type: BannerType.success);
                                    
                                    // 데이터 새로고침
                                    await provider.fetchAllLeaves(forceRefresh: true);
                                  } catch (e) {
                                    
                                    // 로딩 닫기 - loadingContext 사용
                                    if (loadingContext.mounted) {
                                      Navigator.of(loadingContext).pop();
                                    } else {
                                      // 백업 방법 - navigatorContext 사용
                                      try {
                                        navigatorContext.pop();
                                      } catch (e2) {
                                      }
                                    }
                                    
                                    // 에러 메시지
                                    AppBanner.show(savedContext, '수정 중 오류가 발생했습니다: $e', type: BannerType.error);
                                  }
                                },
                                child: Text(
                                  '수정하기',
                                  style: AppTextStyles.sectionSubtitle(context).copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    String confirmText,
    Color confirmColor,
  ) {
    // 아이콘과 색상 결정
    IconData iconData;
    Color iconBgColor;
    
    if (title.contains('삭제')) {
      iconData = Icons.delete_outline;
      iconBgColor = AppColors.error.withValues(alpha:0.1);
    } else if (title.contains('반려')) {
      iconData = Icons.warning_amber_rounded;
      iconBgColor = AppColors.warning.withValues(alpha: 0.1);
    } else if (title.contains('승인')) {
      iconData = Icons.check_circle_outline;
      iconBgColor = AppColors.success.withValues(alpha:0.1);
    } else {
      iconData = Icons.info_outline;
      iconBgColor = AppColors.primary.withValues(alpha:0.1);
    }

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.lgShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 아이콘과 제목 영역
                Padding(
                  padding: const EdgeInsets.only(top: 32, bottom: 20),
                  child: Column(
                    children: [
                      // 아이콘
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconData,
                          size: 40,
                          color: confirmColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 제목
                      Text(
                        title,
                        style: AppTextStyles.sectionTitle(context),
                      ),
                    ],
                  ),
                ),
                
                // 메시지
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    message,
                    style: AppTextStyles.sectionSubtitle(context).copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.normal,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 버튼 영역
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: AppShadows.xsShadow,
                          ),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              '취소',
                              style: AppTextStyles.sectionSubtitle(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: confirmColor.withValues(alpha:0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: confirmColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              confirmText,
                              style: AppTextStyles.sectionSubtitle(context).copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
