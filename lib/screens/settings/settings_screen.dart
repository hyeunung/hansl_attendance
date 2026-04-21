import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/leave_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/responsive_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/font_provider.dart';
import '../inquiry/inquiry_screen.dart';
import '../../services/inquiry_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/cache_recovery_service.dart';
import '../../providers/attendance_provider.dart';
import '../../services/badge_count_service.dart';
import '../../widgets/shared/flat_section.dart';
import '../../widgets/common/notification_banner_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _fontSize = '0% (기본)';
  String _appVersion = '로딩 중...';
  final InquiryService _inquiryService = InquiryService();
  int _inquiryBadgeCount = 0;
  bool _isAdmin = false;
  dynamic _realtimeSubscription;
  bool _isLeaveExpanded = false;
  bool _isLateExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _initInquiryBadge();
    // 폰트 크기 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fontProvider = Provider.of<FontProvider>(context, listen: false);
      setState(() {
        _fontSize = fontProvider.fontSize;
      });
    });
  }

  Future<void> _initInquiryBadge() async {
    await _loadInquiryBadgeCount();
    _setupRealtimeSubscription();
  }

  /// 문의 뱃지 카운트 로드
  Future<void> _loadInquiryBadgeCount() async {
    _isAdmin = await _inquiryService.isAppAdmin();

    int count = 0;
    if (_isAdmin) {
      // 관리자: 미처리 문의 개수
      count = await _inquiryService.getUnprocessedCount();
    } else {
      // 일반 사용자: 미확인 답변 개수
      count = await _inquiryService.getUnreadResponseCount();
    }

    if (mounted) {
      setState(() {
        _inquiryBadgeCount = count;
      });
    }
  }

  /// 실시간 업데이트 구독
  void _setupRealtimeSubscription() {
    if (_realtimeSubscription != null) {
      _inquiryService.unsubscribe(_realtimeSubscription);
      _realtimeSubscription = null;
    }

    // 관리자: 미처리 문의(support_inquires) 변화 감지
    if (_isAdmin) {
      _realtimeSubscription = _inquiryService.subscribeToInquiryUpdates(
        onUpdate: (_) => _loadInquiryBadgeCount(),
      );
      return;
    }

    // 일반 사용자: notifications(inquiry_message/inquiry_resolved) 변화 감지
    _realtimeSubscription = _inquiryService.subscribeToInquiryNotificationUpdates(
      onUpdate: () => _loadInquiryBadgeCount(),
    );
  }

  @override
  void dispose() {
    if (_realtimeSubscription != null) {
      _inquiryService.unsubscribe(_realtimeSubscription);
    }
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '앱 버전 ${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _appVersion = '앱 버전 4.1.7';
      });
    }
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('폰트 크기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFontSizeOption('0% (기본)'),
              _buildFontSizeOption('+15%'),
              _buildFontSizeOption('+30%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFontSizeOption(String size) {
    final isSelected = _fontSize == size;
    return InkWell(
      onTap: () async {
        final fontProvider = Provider.of<FontProvider>(context, listen: false);
        await fontProvider.setFontSize(size);
        setState(() {
          _fontSize = size;
        });
        Navigator.of(context).pop();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Radio<String>(
              value: size,
              groupValue: _fontSize,
              onChanged: (String? value) async {
                if (value != null) {
                  final fontProvider = Provider.of<FontProvider>(
                    context,
                    listen: false,
                  );
                  await fontProvider.setFontSize(value);
                  setState(() {
                    _fontSize = value;
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(width: 8),
            Text(
              size,
              style: AppTextStyles.cardBody(context).copyWith(
                fontSize: ResponsiveUtils.fontSize(context, _getFontSizePreview(size)),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTableRow(BuildContext context, String label, String value, Color valueColor) {
    return FlatTableRow(
      cells: [
        Text(label, style: AppTextStyles.cardBody(context)),
        Text(
          value,
          textAlign: TextAlign.end,
          style: AppTextStyles.cardBody(context).copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
      flexValues: const [1, 1],
    );
  }

  double _getFontSizePreview(String size) {
    switch (size) {
      case '+15%':
        return 19.0;
      case '+30%':
        return 22.0;
      default:
        return 17.0; // 0% (기본)
    }
  }

  void _showInquiryDialog() async {
    // 문의하기 화면으로 이동
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InquiryScreen()),
    );
    // 돌아올 때 뱃지 카운트 재로드
    _loadInquiryBadgeCount();
  }

  void _showAccountDeletionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(
            '계정 삭제',
            style: AppTextStyles.cardTitle(context).copyWith(
              color: AppColors.error,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.\n\n• 출퇴근 기록\n• 연차 신청 내역\n• 개인 정보\n\n이 작업은 되돌릴 수 없습니다.',
              style: AppTextStyles.tableCellSub(context),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('삭제'),
              onPressed: () async {
                Navigator.pop(context);

                // 최종 확인 다이얼로그
                final confirmed = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: const Text('정말 삭제하시겠습니까?'),
                      content: const Text('마지막 확인입니다. 계정을 삭제하시겠습니까?'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('취소'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: const Text('삭제'),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed == true) {
                  await _deleteAccount();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.id;
      final userEmail = userProvider.email;

      if (userId != null && userEmail != null) {
        // Supabase에서 사용자 관련 데이터 삭제
        final supabase = Supabase.instance.client;

        // 1. 출퇴근 기록 삭제
        await supabase
            .from('attendance_records')
            .delete()
            .eq('employee_id', userId);

        // 2. 연차 신청 기록 삭제
        await supabase.from('leave').delete().eq('user_email', userEmail);

        // 3. 직원 정보 삭제
        await supabase.from('employees').delete().eq('id', userId);

        // 4. 로그아웃 (Auth 사용자는 관리자가 별도 삭제)
        await supabase.auth.signOut();

        // 배지 제거
        await BadgeCountService.updateBadgeCount();

        // 5. 자동 로그인 정보 삭제
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('autoLogin', false);
        await prefs.remove('autoLoginEmail');
        await prefs.remove('autoLoginPassword');
      }

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 성공 메시지 표시
      AppBanner.show(context, '계정이 성공적으로 삭제되었습니다.', type: BannerType.success);

      // 로그인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 에러 메시지 표시
      AppBanner.show(context, '계정 삭제 중 오류가 발생했습니다: $e', type: BannerType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    return Consumer<FontProvider>(
      builder: (context, fontProvider, _) {
        // FontProvider 상태가 변경되면 _fontSize 동기화
        if (_fontSize != fontProvider.fontSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _fontSize = fontProvider.fontSize;
            });
          });
        }

        final userProvider = Provider.of<UserProvider>(context);
        final leaveProvider = Provider.of<LeaveProvider>(context);

    // 데이터가 없으면 여기서 로드
    if (!leaveProvider.isLoading && leaveProvider.myLeaves.isEmpty) {
      final email = userProvider.email;
      if (email != null && email.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          leaveProvider.fetchMyLeaves(email: email, forceRefresh: true);
        });
      }
    }

    final employee = userProvider.employee;
    final name = employee?['name'] ?? '-';
    final department = employee?['department'] ?? '-';
    final position = employee?['position'] ?? '-';
    final totalAnnual = leaveProvider.currentGrantedAnnual;
    final usedAnnual = leaveProvider.usedAnnual;
    final remainAnnual = leaveProvider.remainAnnual;
    final isLoading = leaveProvider.isLoading;
    final email = userProvider.email;

    if (email == null || email.isEmpty) {
      // 디버깅 모드에서 핫리로드 등으로 인한 상태 초기화 시 자동으로 로그인 화면으로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
            (route) => false,
          );
        }
      });

      // 로그인 화면으로 이동하는 동안 로딩 표시
      return Scaffold(
        body: Container(
          color: AppColors.backgroundPrimary,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (leaveProvider.error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            '데이터를 불러오지 못했습니다.\n${leaveProvider.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: AppBarTitle('설정'),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // 모든 데이터 새로고침
                final attendanceProvider = Provider.of<AttendanceProvider>(
                  context,
                  listen: false,
                );
                final leaveProvider = Provider.of<LeaveProvider>(
                  context,
                  listen: false,
                );
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );

                await Future.wait([
                  attendanceProvider.forceRefreshAll(),
                  _loadInquiryBadgeCount(),
                  if (userProvider.email != null) ...[
                    leaveProvider.fetchAllLeaves(forceRefresh: true),
                    leaveProvider.fetchMyLeaves(
                      email: userProvider.email!,
                      forceRefresh: true,
                    ),
                  ],
                ]);
                if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // 프로필 섹션
                  FlatSectionHeader(title: '프로필'),
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 16),
                      vertical: ResponsiveUtils.spacing(context, 16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: ResponsiveUtils.spacing(context, 52),
                          height: ResponsiveUtils.spacing(context, 52),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 26),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0] : '-',
                              style: AppTextStyles.statNumber(context, color: Colors.white).copyWith(
                                fontSize: ResponsiveUtils.fontSize(context, 24),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTextStyles.sectionSubtitle(context).copyWith(
                                  fontSize: ResponsiveUtils.fontSize(context, 20),
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 2),
                              ),
                              Text(
                                '${(department?.isNotEmpty ?? false) ? department : '-'} / ${(position?.isNotEmpty ?? false) ? position : '-'}',
                                style: AppTextStyles.listSubtitle(context).copyWith(
                                  fontSize: ResponsiveUtils.fontSize(context, 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0.5, thickness: 0.5, color: AppColors.borderLight),

                  // 연차 현황 섹션 (토글)
                  FlatToggleSection(
                    title: '연차 현황',
                    icon: Icons.event_available,
                    color: AppColors.primary,
                    isExpanded: _isLeaveExpanded,
                    onTap: () => setState(() => _isLeaveExpanded = !_isLeaveExpanded),
                    children: [
                      FlatTableColumnHeader(
                        columns: const [
                          FlatColumn(label: '항목', flex: 1),
                          FlatColumn(label: '일수', flex: 1, align: TextAlign.end),
                        ],
                      ),
                      _buildStatTableRow(context, '총 연차', '$totalAnnual일', AppColors.textPrimary),
                      _buildStatTableRow(context, '소모 연차', '$usedAnnual일', AppColors.textPrimary),
                      _buildStatTableRow(context, '잔여 연차', '$remainAnnual일', remainAnnual <= 0 ? AppColors.error : AppColors.primary),
                    ],
                  ),

                  // 지각 현황 섹션 (토글, 기본 펼침)
                  Builder(
                    builder: (context) {
                      final attendanceProvider = Provider.of<AttendanceProvider>(context);
                      final monthlyLate = attendanceProvider.monthlyLateCount;
                      final yearlyLate = attendanceProvider.yearlyLateCount;
                      return FlatToggleSection(
                        title: '지각 현황',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.error,
                        isExpanded: _isLateExpanded,
                        onTap: () => setState(() => _isLateExpanded = !_isLateExpanded),
                        children: [
                          FlatTableColumnHeader(
                            columns: const [
                              FlatColumn(label: '기간', flex: 1),
                              FlatColumn(label: '횟수', flex: 1, align: TextAlign.end),
                            ],
                          ),
                          _buildStatTableRow(context, '이번 달', '$monthlyLate회', monthlyLate > 0 ? AppColors.error : AppColors.textPrimary),
                          _buildStatTableRow(context, '올해', '$yearlyLate회', yearlyLate > 0 ? AppColors.error : AppColors.textPrimary),
                        ],
                      );
                    },
                  ),

                  // 앱 설정 섹션
                  FlatSectionHeader(title: '앱 설정'),
                  FlatListTile(
                    title: '폰트 크기',
                    value: _fontSize,
                    leading: Icon(
                      Icons.text_fields,
                      size: ResponsiveUtils.iconSize(context, 20),
                      color: AppColors.info,
                    ),
                    onTap: _showFontSizeDialog,
                  ),
                  FlatListTile(
                    title: _isAdmin ? '문의 관리' : '문의하기',
                    value: _isAdmin
                        ? (_inquiryBadgeCount > 0
                            ? '미처리 $_inquiryBadgeCount건'
                            : '처리 완료')
                        : null,
                    leading: Icon(
                      Icons.support_agent,
                      size: ResponsiveUtils.iconSize(context, 20),
                      color: AppColors.success,
                    ),
                    trailing: _inquiryBadgeCount > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: ResponsiveUtils.spacing(context, 22),
                                height: ResponsiveUtils.spacing(context, 22),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _inquiryBadgeCount.toString(),
                                    style: AppTextStyles.tableHeader(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: AppColors.textTertiary,
                              ),
                            ],
                          )
                        : null,
                    onTap: _showInquiryDialog,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: ResponsiveUtils.spacing(context, 18),
          top: ResponsiveUtils.spacing(context, 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 개발자 전용 캐시 복원 버튼
            if (kDebugMode) ...[
              Padding(
                padding: EdgeInsets.only(
                  bottom: ResponsiveUtils.spacing(context, 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: ResponsiveUtils.spacing(context, 150),
                      height: ResponsiveUtils.spacing(context, 36),
                      child: TextButton.icon(
                        icon: Icon(
                          Icons.restore,
                          color: AppColors.info,
                          size: ResponsiveUtils.iconSize(context, 18),
                        ),
                        label: Text(
                          '캐시 복원',
                          style: AppTextStyles.tableCellSub(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          shape: null,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () async {
                          // 캐시 내용 확인
                          await CacheRecoveryService.printCacheContents();

                          // 캐시에서 DB로 복원
                          await CacheRecoveryService.recoverLeaveDataFromCache();

                          // 성공 메시지
                          if (mounted) {
                            AppBanner.show(context, '캐시 데이터 복원 완료! 디버그 콘솔을 확인하세요.', type: BannerType.info);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: ResponsiveUtils.spacing(context, 120),
                  height: ResponsiveUtils.spacing(context, 36),
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.delete_forever,
                      color: AppColors.error,
                      size: ResponsiveUtils.iconSize(context, 18),
                    ),
                    label: Text(
                      '계정 삭제',
                      style: AppTextStyles.tableCellSub(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: null,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _showAccountDeletionDialog,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 20)),
                SizedBox(
                  width: ResponsiveUtils.spacing(context, 120),
                  height: ResponsiveUtils.spacing(context, 36),
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.logout,
                      color: AppColors.error,
                      size: ResponsiveUtils.iconSize(context, 18),
                    ),
                    label: Text(
                      '로그아웃',
                      style: AppTextStyles.tableCellSub(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: null,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () async {
                      // Supabase 세션 종료
                      final supabase = Supabase.instance.client;
                      await supabase.auth.signOut();

                      // 배지 제거
                      await BadgeCountService.updateBadgeCount();
                      BadgeCountService.removeSubscriptions();

                      // SharedPreferences 초기화
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('autoLogin', false);
                      await prefs.remove('autoLoginEmail');
                      await prefs.remove('autoLoginPassword');

                      // 알림 Provider 초기화
                      if (mounted) {
                        Provider.of<NotificationProvider>(
                          context,
                          listen: false,
                        ).clear();
                      }

                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 6)),
            Text(
              _appVersion,
              style: AppTextStyles.listSubtitle(context),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
