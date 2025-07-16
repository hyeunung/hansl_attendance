import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/leave_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _approvalNoti = true;
  String _fontSize = '보통';
  String _appVersion = '로딩 중...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    Future.microtask(() async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final email = userProvider.email;
      if (email != null && email.isNotEmpty) {
        final supabaseService = SupabaseService();
        final emp = await supabaseService.getEmployeeByEmail(email);
        if (emp != null) {
          userProvider.setEmployee(emp);
        }
        await leaveProvider.fetchMyLeaves(email: email);
      }
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '앱 버전 ${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _appVersion = '앱 버전 1.0.1+3';
      });
    }
  }

  void _showInquiryDialog() {
    final TextEditingController _controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('문의하기', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: _controller,
              maxLines: 5,
              placeholder: '문의 내용을 입력하세요',
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('보내기'),
              onPressed: () {
                // 문의 내용 전송 로직 (추후 구현)
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('문의가 접수되었습니다.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, LeaveProvider>(
      builder: (context, userProvider, leaveProvider, _) {
        final employee = userProvider.employee;
        final name = employee?['name'] ?? '-';
        final department = employee?['department'] ?? '-';
        final position = employee?['position'] ?? '-';
        final totalAnnual = leaveProvider.currentGrantedAnnual;
        final remainAnnual = leaveProvider.remainAnnual;
        final usedAnnual = (totalAnnual - remainAnnual).clamp(0, totalAnnual);
        final isLoading = leaveProvider.isLoading;
        final email = userProvider.email;
        if (email == null || email.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('로그인 정보가 없습니다. 다시 로그인 해주세요.', style: TextStyle(fontSize: 16))),
          );
        }
        if (leaveProvider.error != null) {
          return Scaffold(
            body: Center(child: Text('데이터를 불러오지 못했습니다.\n${leaveProvider.error}', textAlign: TextAlign.center)),
          );
        }
    return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            ),
            centerTitle: true,
                          title: Text(
                '설정',
                style: AppTextStyles.appBarTitle(context),
              ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 프로필 카드
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E90FF), Color(0xFF00BFFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0] : '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                                  Text(
                                    '${(department?.isNotEmpty ?? false) ? department : '-'} • ${(position?.isNotEmpty ?? false) ? position : '-'}',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 16,
                                      color: const Color(0xFF8E8E93),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // 연차 현황
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '📅 연차 현황',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFF2F2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$totalAnnual',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E90FF),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '총 연차',
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFF2F2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$usedAnnual',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E90FF),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '소모 연차',
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFF2F2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$remainAnnual',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E90FF),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '잔여',
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 앱 설정
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                '앱 설정',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C1C1E),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // 글꼴 크기
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E5F5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.text_fields, size: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '글꼴 크기',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _fontSize,
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 18,
                                      color: const Color(0xFF8E8E93),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFFC7C7CC),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 문의하기
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ListTile(
                          minLeadingWidth: 0,
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF8E8E93)),
                          ),
                          title: const Text(
                            '문의하기',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          onTap: _showInquiryDialog,
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  height: 36,
                  child: TextButton.icon(
                    icon: const Icon(Icons.logout, color: Color(0xFFFF3B30), size: 18),
                    label: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3B30), fontSize: 14)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: null,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('autoLogin', false);
                      await prefs.remove('autoLoginEmail');
                      await prefs.remove('autoLoginPassword');
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(_appVersion, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}
