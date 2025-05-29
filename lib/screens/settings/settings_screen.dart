import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/leave_provider.dart';
import '../../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _approvalNoti = true;
  bool _darkMode = false;
  String _fontSize = '보통';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final email = userProvider.email;
      if (email != null && email.isNotEmpty) {
        await leaveProvider.fetchMyLeaves(email);
        if (userProvider.employee == null) {
          final supabaseService = SupabaseService();
          final emp = await supabaseService.getEmployeeByEmail(email);
          if (emp != null) userProvider.setEmployee(emp);
        }
      }
    });
  }

  void _showInquiryDialog() {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('문의하기', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '문의 내용을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                // 문의 내용 전송 로직 (추후 구현)
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('문의가 접수되었습니다.')),
                );
              },
              child: const Text('보내기'),
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
        final isLoading = leaveProvider.isLoading || employee == null;
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
          backgroundColor: const Color(0xFFF6F7FA),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
            title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
          ),
          body: isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        children: [
                          // 프로필 카드
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [AppShadows.card],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2196F3),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    name.isNotEmpty ? name[0] : '-',
                                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                      const SizedBox(height: 4),
                                      Text('$department · $position', style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 연차 현황 카드
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [AppShadows.card],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, size: 36, color: Color(0xFFB0B0B0)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _annualStatBox(totalAnnual.toString(), '총 연차'),
                                      _annualStatBox(usedAnnual.toString(), '사용'),
                                      _annualStatBox(remainAnnual.toString(), '잔여'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 알림 설정
                          const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF888888))),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [AppShadows.card],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications, color: Color(0xFFFFC107), size: 22),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('승인/반려 알림', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      SizedBox(height: 2),
                                      Text('신청한 연차/출장의 승인 결과를 알려드려요', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: CupertinoSwitch(
                                    value: _approvalNoti,
                                    onChanged: (v) => setState(() => _approvalNoti = v),
                                    activeColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 앱 설정
                          const Text('앱 설정', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF888888))),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [AppShadows.card],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.nightlight_round, color: Color(0xFFFBC02D)),
                                  title: const Text('다크모드', style: TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: Transform.scale(
                                    scale: 0.8,
                                    child: CupertinoSwitch(
                                      value: _darkMode,
                                      onChanged: (v) => setState(() => _darkMode = v),
                                      activeColor: AppColors.primary,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                ListTile(
                                  leading: const Icon(Icons.abc, color: Color(0xFFB0B0B0)),
                                  title: const Text('글꼴 크기', style: TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: DropdownButton<String>(
                                    value: _fontSize,
                                    items: const [
                                      DropdownMenuItem(value: '작게', child: Text('작게')),
                                      DropdownMenuItem(value: '보통', child: Text('보통')),
                                      DropdownMenuItem(value: '크게', child: Text('크게')),
                                    ],
                                    onChanged: (v) => setState(() => _fontSize = v!),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 문의하기
                          ListTile(
                            leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF888888)),
                            title: const Text('문의하기', style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
                            onTap: _showInquiryDialog,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            tileColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    // 로그아웃 버튼 하단 중앙 배치
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32, top: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 180,
                            height: 48,
                            child: TextButton.icon(
                              icon: const Icon(Icons.logout, color: Color(0xFFFF3B30)),
                              label: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3B30), fontSize: 17)),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFFFF5F5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                // 로그아웃 로직 (추후 구현)
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('앱 버전 1.0.0', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _annualStatBox(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
      ],
    );
  }
} 