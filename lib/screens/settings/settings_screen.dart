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
import '../../providers/font_provider.dart';
import '../../services/slack_service.dart';
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
      final fontProvider = Provider.of<FontProvider>(context, listen: false);
      
      // 글꼴 크기 로드
      await fontProvider.loadFontSize();
      setState(() {
        _fontSize = fontProvider.fontSize;
      });
      
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

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('글꼴 크기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFontSizeOption('작게'),
              _buildFontSizeOption('보통'),
              _buildFontSizeOption('크게'),
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
                  final fontProvider = Provider.of<FontProvider>(context, listen: false);
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
              style: TextStyle(
                fontSize: _getFontSizePreview(size),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getFontSizePreview(String size) {
    switch (size) {
      case '작게':
        return 14.0;
      case '크게':
        return 20.0;
      default:
        return 17.0; // 보통
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
              onPressed: () async {
                final content = _controller.text.trim();
                
                if (content.isEmpty) {
                  // 문의 내용이 비어있으면 에러 표시
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('문의 내용을 입력해주세요.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // 로딩 표시를 위해 다이얼로그 닫기
                Navigator.pop(context);
                
                // 로딩 인디케이터 표시
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                try {
                  // 현재 사용자 정보 가져오기
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final userName = userProvider.name ?? '알 수 없음';
                  final userEmail = userProvider.email ?? '알 수 없음';
                  
                  // 슬랙으로 문의 전송
                  final slackService = SlackService();
                  final success = await slackService.sendInquiryToSlack(
                    inquiryContent: content,
                    userEmail: userEmail,
                    userName: userName,
                  );
                  
                  // 로딩 다이얼로그 닫기
                  Navigator.pop(context);
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 문의가 관리자에게 성공적으로 전송되었습니다!\n곧 답변을 받으실 수 있습니다.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ 문의 전송에 실패했습니다.\n관리자가 슬랙 설정을 확인중일 수 있습니다.\n잠시 후 다시 시도하거나 직접 연락해주세요.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 6),
                      ),
                    );
                  }
                } catch (e) {
                  // 로딩 다이얼로그 닫기
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
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
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                  child: Column(
                    children: [
                      // 프로필 카드
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: ResponsiveUtils.spacing(context, 3),
                              offset: Offset(0, ResponsiveUtils.spacing(context, 1)),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                        child: Row(
                          children: [
                            Container(
                              width: ResponsiveUtils.spacing(context, 60),
                              height: ResponsiveUtils.spacing(context, 60),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E90FF), Color(0xFF00BFFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 30)),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0] : '-',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 16)),
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
                      
                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),

                      // 연차 현황
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: ResponsiveUtils.spacing(context, 3),
                              offset: Offset(0, ResponsiveUtils.spacing(context, 1)),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '📅 연차 현황',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1C1C1E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: ResponsiveUtils.spacing(context, 16), 
                                      horizontal: ResponsiveUtils.spacing(context, 8)
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                                      border: Border.all(color: const Color(0xFFF2F2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$totalAnnual',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E90FF),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                                        Text(
                                          '총 연차',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: ResponsiveUtils.spacing(context, 16), 
                                      horizontal: ResponsiveUtils.spacing(context, 8)
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                                      border: Border.all(color: const Color(0xFFF2F2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$usedAnnual',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E90FF),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                                        Text(
                                          '소모 연차',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: ResponsiveUtils.spacing(context, 16), 
                                      horizontal: ResponsiveUtils.spacing(context, 8)
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                                      border: Border.all(color: const Color(0xFFF2F2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$remainAnnual',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E90FF),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                                        Text(
                                          '잔여',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF8E8E93),
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

                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),

                      // 앱 설정
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: ResponsiveUtils.spacing(context, 3),
                              offset: Offset(0, ResponsiveUtils.spacing(context, 1)),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                ResponsiveUtils.spacing(context, 20), 
                                ResponsiveUtils.spacing(context, 16), 
                                ResponsiveUtils.spacing(context, 20), 
                                ResponsiveUtils.spacing(context, 8)
                              ),
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
                            InkWell(
                              onTap: () => _showFontSizeDialog(),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(context, 20), 
                                  vertical: ResponsiveUtils.spacing(context, 16)
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                  Container(
                                    width: ResponsiveUtils.spacing(context, 28),
                                    height: ResponsiveUtils.spacing(context, 28),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E5F5),
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.text_fields, size: ResponsiveUtils.iconSize(context, 14)),
                                    ),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 12)),
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
                                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                  Icon(
                                    Icons.chevron_right,
                                    color: const Color(0xFFC7C7CC),
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),

                      // 문의하기
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: ResponsiveUtils.spacing(context, 3),
                              offset: Offset(0, ResponsiveUtils.spacing(context, 1)),
                            ),
                          ],
                        ),
                        child: ListTile(
                          minLeadingWidth: 0,
                          leading: Container(
                            width: ResponsiveUtils.spacing(context, 28),
                            height: ResponsiveUtils.spacing(context, 28),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.chat_bubble_outline, size: ResponsiveUtils.iconSize(context, 18), color: const Color(0xFF8E8E93)),
                          ),
                          title: Text(
                            '문의하기',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          onTap: _showInquiryDialog,
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveUtils.spacing(context, 18), 
              top: ResponsiveUtils.spacing(context, 8)
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: ResponsiveUtils.spacing(context, 120),
                  height: ResponsiveUtils.spacing(context, 36),
                  child: TextButton.icon(
                    icon: Icon(Icons.logout, color: const Color(0xFFFF3B30), size: ResponsiveUtils.iconSize(context, 18)),
                    label: Text('로그아웃', style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.bold, color: const Color(0xFFFF3B30), fontSize: 14)),
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
                SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                Text(_appVersion, style: ResponsiveUtils.getTextStyle(context, color: const Color(0xFFB0B0B0), fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}
