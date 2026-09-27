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
import '../../widgets/adaptive/detail_pane.dart';
import '../../widgets/shared/flat_section.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../utils/user_role_helper.dart';
import '../admin/admin_attendance_screen.dart';
import '../../widgets/common/notification_bell_button.dart';
import 'notification_settings_screen.dart';
import '../../widgets/adaptive/pane_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _fontSize = FontProvider.defaultSize;
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
        _appVersion = '앱 버전 4.3.1+293';
      });
    }
  }

  /// 폰트 크기 조절 다이얼로그
  /// iOS(설정>텍스트 크기) / Android(설정>글꼴 크기) 표준을 따라
  /// 미리보기 + 눈금 슬라이더 구성. 선택 즉시 화면에 반영되고 '확인'에서 저장한다.
  /// 폰트 크기 조절 다이얼로그
  /// 행을 고르면 뒤 화면까지 즉시 반영되고, '확인'을 눌러야 저장된다.
  void _showFontSizeDialog() {
    final fontProvider = context.read<FontProvider>();
    final originalSize = fontProvider.fontSize;
    bool confirmed = false;

    DetailPane.dialog<void>(
      context,
      key: 'font-size',
      builder: (BuildContext dialogContext) {
        return Consumer<FontProvider>(
          builder: (context, provider, _) {
            return PaneAlertDialog(
              titlePadding: EdgeInsets.fromLTRB(
                ResponsiveUtils.spacing(context, 16),
                ResponsiveUtils.spacing(context, 16),
                ResponsiveUtils.spacing(context, 16),
                ResponsiveUtils.spacing(context, 6),
              ),
              contentPadding: EdgeInsets.zero,
              actionsPadding: EdgeInsets.fromLTRB(
                ResponsiveUtils.spacing(context, 12),
                ResponsiveUtils.spacing(context, 4),
                ResponsiveUtils.spacing(context, 12),
                ResponsiveUtils.spacing(context, 8),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('폰트 크기', style: AppTextStyles.appBarTitle(context)),
                  SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                  Text(
                    '선택하면 화면에 바로 적용되고, 확인을 눌러야 저장됩니다.',
                    style: AppTextStyles.listSubtitle(context),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: FontProvider.options
                    .map((size) => _buildFontSizeOption(size, provider))
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    provider.previewFontSize(originalSize);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    confirmed = true;
                    await provider.setFontSize(provider.fontSize);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // 바깥 영역 탭 등으로 닫힌 경우에도 저장 없이 원래 크기로 되돌린다
      if (!confirmed) {
        fontProvider.previewFontSize(originalSize);
      }
      if (!mounted) return;
      setState(() {
        _fontSize = fontProvider.fontSize;
      });
    });
  }

  Widget _buildFontSizeOption(String size, FontProvider provider) {
    final isSelected = provider.fontSize == size;

    return InkWell(
      onTap: () => provider.previewFontSize(size),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 16),
          vertical: ResponsiveUtils.spacing(context, 10),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: ResponsiveUtils.iconSize(context, 18),
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            SizedBox(width: ResponsiveUtils.spacing(context, 10)),
            Expanded(
              child: Text(
                size,
                style: AppTextStyles.tableCell(
                  context,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ).copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            // 현재 배율과 무관하게 각 단계의 실제 크기를 보여준다
            Text(
              '가나다 Aa',
              style: AppTextStyles.tableCell(
                context,
                color: AppColors.textSecondary,
              ).copyWith(
                fontSize: _fontPreviewBaseSize *
                    ResponsiveUtils.getScaleFactor(context) *
                    FontProvider.scaleOf(size),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 옵션별 미리보기 기준 크기 (여기에 단계별 배율을 곱해서 표시)
  static const double _fontPreviewBaseSize = 13.0;

  Widget _buildInquiryTile(BuildContext context) {
    return FlatListTile(
      title: _isAdmin ? '문의 관리' : '문의하기',
      value: _isAdmin && _inquiryBadgeCount == 0 ? '처리 완료' : null,
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
                  constraints: BoxConstraints(
                    minWidth: ResponsiveUtils.spacing(context, 18),
                  ),
                  height: ResponsiveUtils.spacing(context, 18),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacing(context, 5),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 6),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _inquiryBadgeCount.toString(),
                      style: AppTextStyles.compactLabel(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            )
          : null,
      onTap: _showInquiryDialog,
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


  /// 프로필을 누르면 계정 화면(로그아웃·계정 삭제)을 연다.
  /// 펼친 폴더블에서는 오른쪽 패널에, 폰에서는 전체 화면으로 열린다.
  void _openAccount() {
    final employee =
        Provider.of<UserProvider>(context, listen: false).employee;
    final name = (employee?['name'] ?? '').toString();
    final department = (employee?['department'] ?? '').toString();
    final position = (employee?['position'] ?? '').toString();
    final email = (employee?['email'] ?? '').toString();
    DetailPane.push<void>(
      context,
      key: 'account',
      builder: (_) => _AccountPage(
        name: name,
        affiliation:
            '${department.isNotEmpty ? department : '-'} / ${position.isNotEmpty ? position : '-'}',
        email: email,
        onLogout: _logout,
        onDeleteAccount: _showAccountDeletionDialog,
        onRestoreCache: kDebugMode ? _restoreCache : null,
      ),
    );
  }

  Future<void> _restoreCache() async {
    final ok = await _confirm(
      title: '캐시 복원',
      message: '기기에 남은 연차 캐시를 DB로 복원합니다. 진행하시겠습니까?',
      confirmText: '복원',
      icon: Icons.restore,
    );
    if (!ok) return;

    // 캐시 내용 확인
    await CacheRecoveryService.printCacheContents();

    // 캐시에서 DB로 복원
    await CacheRecoveryService.recoverLeaveDataFromCache();

    // 성공 메시지
    if (!mounted) return;
    AppBanner.show(context, '캐시 데이터 복원 완료! 디버그 콘솔을 확인하세요.', type: BannerType.info);
  }

  Future<void> _logout() async {
    final ok = await _confirm(
      title: '로그아웃',
      message: '로그아웃하시겠습니까?\n자동 로그인 정보도 함께 해제됩니다.',
      confirmText: '로그아웃',
      icon: Icons.logout,
      color: AppColors.error,
    );
    if (!ok) return;

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
  }

  void _showInquiryDialog() async {
    // 문의하기 화면으로 이동
    await DetailPane.push(
      context,
      builder: (context) => const InquiryScreen(),
      key: 'inquiry',
    );
    // 돌아올 때 뱃지 카운트 재로드
    _loadInquiryBadgeCount();
  }

  /// 앱 공통 확인창 (제목 18 + 아이콘, 본문 12, 취소/확인)
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    IconData icon = Icons.help_outline,
    Color color = AppColors.primary,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: AppTextStyles.cardBody(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _showAccountDeletionDialog() async {
    final first = await _confirm(
      title: '계정 삭제',
      message: '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.\n\n'
          '• 출퇴근 기록\n• 연차 신청 내역\n• 개인 정보\n\n'
          '이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
      icon: Icons.delete_forever,
      color: AppColors.error,
    );
    if (!first || !mounted) return;

    // 최종 확인
    final second = await _confirm(
      title: '정말 삭제하시겠습니까?',
      message: '마지막 확인입니다. 계정을 삭제하시겠습니까?',
      confirmText: '삭제',
      icon: Icons.warning_amber_rounded,
      color: AppColors.error,
    );
    if (second) await _deleteAccount();
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
      if (!mounted) return;
      Navigator.pop(context);

      // 성공 메시지 표시
      if (!mounted) return;
      AppBanner.show(context, '계정이 성공적으로 삭제되었습니다.', type: BannerType.success);

      // 로그인 화면으로 이동
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (!mounted) return;
      Navigator.pop(context);

      // 에러 메시지 표시
      if (!mounted) return;
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
        actions: const [NotificationBellButton()],
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
                  FlatCard(
                    margin: EdgeInsets.fromLTRB(
                      ResponsiveUtils.spacing(context, 16),
                      ResponsiveUtils.spacing(context, 10),
                      ResponsiveUtils.spacing(context, 16),
                      ResponsiveUtils.spacing(context, 8),
                    ),
                    child: Column(children: [
                  FlatSectionHeader(title: '프로필'),
                  InkWell(
                    onTap: _openAccount,
                    child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 14),
                      vertical: ResponsiveUtils.spacing(context, 10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: ResponsiveUtils.spacing(context, 38),
                          height: ResponsiveUtils.spacing(context, 38),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 19),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0] : '-',
                              style: AppTextStyles.statNumber(context, color: Colors.white).copyWith(
                                fontSize: ResponsiveUtils.fontSize(context, 15),
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
                                  fontSize: ResponsiveUtils.fontSize(context, 18),
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 2),
                              ),
                              Text(
                                '${(department?.isNotEmpty ?? false) ? department : '-'} / ${(position?.isNotEmpty ?? false) ? position : '-'}',
                                style: AppTextStyles.listSubtitle(context).copyWith(
                                  fontSize: ResponsiveUtils.fontSize(context, 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: ResponsiveUtils.iconSize(context, 18),
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                  ),
                    ]),
                  ),

                  // 연차/지각 현황 (토글 카드)
                  FlatCard(
                    child: Column(children: [
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

                    ]),
                  ),

                  // 관리자 전용 섹션 (hr / SuperAdmin)
                  if (UserRoleHelper.canManageAttendance(
                      UserRoleHelper.getRoles(employee))) ...[
                    FlatCard(
                      child: Column(children: [
                    FlatSectionHeader(title: '관리자 전용'),
                    FlatListTile(
                      title: '전체 근태 관리',
                      leading: Icon(
                        Icons.admin_panel_settings,
                        size: ResponsiveUtils.iconSize(context, 20),
                        color: AppColors.primary,
                      ),
                      onTap: () {
                        DetailPane.push(
                          context,
                          builder: (_) => const AdminAttendanceScreen(),
                          key: 'admin-attendance',
                        );
                      },
                    ),
                    if (_isAdmin) _buildInquiryTile(context),
                      ]),
                    ),
                  ],

                  // 앱 설정 섹션
                  FlatCard(
                    child: Column(children: [
                  FlatSectionHeader(title: '앱 설정'),
                  FlatListTile(
                    title: '푸시 알림',
                    leading: Icon(
                      Icons.notifications_outlined,
                      size: ResponsiveUtils.iconSize(context, 20),
                      color: AppColors.warning,
                    ),
                    onTap: () {
                      // 펼침에서는 푸시 알림이 오른쪽 패널의 기본 화면이므로 상세만 닫는다
                      if (DetailPaneScope.expandedOf(context) != null) {
                        DetailPane.close(context);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
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
                  if (!_isAdmin) _buildInquiryTile(context),
                    ]),
                  ),
                ],
              ),
            ),
      // 하단에는 앱 버전만 표시 (로그아웃·계정 삭제는 프로필 → 계정 화면으로 이동)
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: ResponsiveUtils.spacing(context, 18),
          top: ResponsiveUtils.spacing(context, 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

/// 프로필을 눌렀을 때 열리는 계정 화면: 내 정보 + 로그아웃 · 계정 삭제.
class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.name,
    required this.affiliation,
    required this.email,
    required this.onLogout,
    required this.onDeleteAccount,
    this.onRestoreCache,
  });

  final String name;
  final String affiliation;
  final String email;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback? onRestoreCache;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: AppBarTitle('계정'),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: ResponsiveUtils.spacing(context, 10),
          bottom: ResponsiveUtils.spacing(context, 20),
        ),
        children: [
          FlatCard(
            child: Column(
              children: [
                const FlatSectionHeader(title: '내 정보'),
                FlatInfoRow(label: '이름', value: name.isNotEmpty ? name : '-'),
                FlatInfoRow(label: '소속', value: affiliation),
                FlatInfoRow(label: '이메일', value: email.isNotEmpty ? email : '-'),
              ],
            ),
          ),
          FlatCard(
            child: Column(
              children: [
                const FlatSectionHeader(title: '계정 관리'),
                FlatListTile(
                  title: '로그아웃',
                  leading: Icon(
                    Icons.logout,
                    size: ResponsiveUtils.iconSize(context, 20),
                    color: AppColors.textSecondary,
                  ),
                  onTap: onLogout,
                ),
                FlatListTile(
                  title: '계정 삭제',
                  titleColor: AppColors.error,
                  leading: Icon(
                    Icons.delete_forever,
                    size: ResponsiveUtils.iconSize(context, 20),
                    color: AppColors.error,
                  ),
                  onTap: onDeleteAccount,
                ),
              ],
            ),
          ),
          if (onRestoreCache != null)
            FlatCard(
              child: Column(
                children: [
                  const FlatSectionHeader(title: '개발자'),
                  FlatListTile(
                    title: '캐시 복원',
                    leading: Icon(
                      Icons.restore,
                      size: ResponsiveUtils.iconSize(context, 20),
                      color: AppColors.info,
                    ),
                    onTap: onRestoreCache!,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
