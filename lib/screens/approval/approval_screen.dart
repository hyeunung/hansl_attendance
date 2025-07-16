import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_strings.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => Provider.of<LeaveProvider>(context, listen: false).fetchAllLeaves());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final role = employee?['role'];
    final name = employee?['name'];
    final department = employee?['department'];
    final attendanceRole = employee?['attendance_role'];
    
    // Admin 역할 확인 (승인/반려 권한 체크용)
    final bool isAdmin = attendanceRole != null && 
                        attendanceRole is List && 
                        attendanceRole.contains('admin');
    
    // manager별 승인 가능 부서 매핑 (조회 권한용)
    final Map<String, List<String>> managerDepartments = {
      '양승진': ['개발1팀', '개발2팀'],
      '최창열': ['개발3팀'],
      '이정화': ['CAD'],
      '조근일': ['연구소'],
      '황연순': ['경영지원팀'],
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAdmin ? '연차/출장 관리' : '팀원 승인',
              style: AppTextStyles.appBarTitle(context),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ADMIN',
                      style: TextStyle(
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          List<Map<String, dynamic>> allLeaves = provider.allLeaves;
          
          print('🔍 ApprovalScreen - 전체 데이터 수: ${allLeaves.length}');
          print('👤 현재 사용자: $name (role: $role, isAdmin: $isAdmin)');
          print('🏢 현재 부서: $department');
          
          if (isAdmin) {
            // Admin: 모든 신청 표시 (본인 포함)
            final beforeFilter = allLeaves.length;
            // Admin은 모든 신청을 볼 수 있음 (필터링 없음)
            print('👑 Admin 필터링: $beforeFilter -> ${allLeaves.length} (모든 신청 표시)');
          } else if (managerDepartments.containsKey(name)) {
            // Manager: 자신 부서의 일반직원 신청만 표시 (Manager 신청 제외)
            final myDepts = managerDepartments[name]!;
            final beforeFilter = allLeaves.length;
            allLeaves = allLeaves.where((l) {
              final emp = l['employees'];
              final leaveDept = emp is Map ? emp['department'] : null;
              final requesterName = l['name'] ?? '';
              final requesterEmail = l['user_email'] ?? '';
              
              // Manager 신청과 Admin 신청은 제외
              if (AppStrings.managerNames.contains(requesterName) || 
                  requesterEmail == AppStrings.adminEmail) {
                return false;
              }
              
              // 자신 부서 직원만
              return leaveDept != null && myDepts.contains(leaveDept);
            }).toList();
            print('🏢 Manager 필터링: $beforeFilter -> ${allLeaves.length} (부서: $myDepts)');
          }
          
          final pending = allLeaves.where((l) => l['status'] == 'pending').toList();
          final done = allLeaves.where((l) => l['status'] != 'pending').toList();
          final thisMonth = DateTime.now().month;
          final thisMonthDone = done.where((l) => DateTime.parse(l['created_at']).month == thisMonth).toList();
          
          print('📊 최종 결과: pending=${pending.length}, done=${done.length}, thisMonth=${thisMonthDone.length}');
          
          // pending 데이터 상세 출력
          for (final leave in pending) {
            final emp = leave['employees'];
            final dept = emp is Map ? emp['department'] : 'Unknown';
            print('⏳ Pending: ${leave['name']} ($dept) - ${leave['type']} (${leave['start_date']} ~ ${leave['end_date']})');
          }
          
          return Column(
            children: [
              // Tab Navigation with updated design
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [AppShadows.card],
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('대기중'),
                    )),
                    Tab(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('처리완료'),
                    )),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF8E8E93),
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  labelPadding: EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 대기중 탭
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              _statCard('승인 대기', pending.length),
                              const SizedBox(width: 12),
                              _statCard('이번 달 처리', thisMonthDone.length),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Pending Requests Container
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [AppShadows.card],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '승인 대기 목록',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(thickness: 2, color: Color(0xFFE0E3E8)),
                                  const SizedBox(height: 16),
                                  if (pending.isEmpty)
                                    const Text(
                                      '승인 대기 내역이 없습니다.',
                                      style: TextStyle(color: Color(0xFF8E8E93)),
                                    ),
                                  ...pending.map((l) => _approvalCard(context, l, provider, canApprove: true)).toList(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 100), // Bottom padding for navigation
                        ],
                      ),
                    ),
                    // 처리완료 탭
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [AppShadows.card],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '처리 완료 내역',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (done.isEmpty)
                                    const Text(
                                      '처리 완료 내역이 없습니다.',
                                      style: TextStyle(color: Color(0xFF8E8E93)),
                                    ),
                                  ...done.map((l) => _approvalCard(context, l, provider, showButtons: false, canApprove: false)).toList(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 100), // Bottom padding for navigation
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [AppShadows.card],
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontWeight: FontWeight.w700,
                fontSize: 28,
                color: const Color(0xFF1E90FF),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 4)),
            Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                color: const Color(0xFF8E8E93),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvalCard(BuildContext context, Map<String, dynamic> l, LeaveProvider provider, {bool showButtons = true, bool canApprove = false}) {
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
    final period = '${DateFormat('yyyy.MM.dd').format(start)} ~ ${DateFormat('yyyy.MM.dd').format(end)} ($days일)';
    final createdAt = DateFormat('yyyy.MM.dd').format(DateTime.parse(l['created_at']));
    final reason = l['reason'] ?? '-';
    final status = l['status'];
    final dest = l['destination'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 이름, 유형, 상태
          Row(
            children: [
              Icon(Icons.person, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(typeLabel, style: TextStyle(color: typeTextColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 14),
          // 상세 정보
          _infoRow(Icons.date_range, '기간', period),
          if (isBiztrip && dest.isNotEmpty) _infoRow(Icons.place, '목적지', dest),
          _infoRow(Icons.calendar_today, '신청일', createdAt),
          const SizedBox(height: 14),
          // 사유
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(reason, style: const TextStyle(fontSize: 16, color: Color(0xFF6C757D))),
          ),
          if (showButtons && status == 'pending' && canApprove) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '반려 확인',
                          '$name님의 $typeLabel 신청을 반려하시겠습니까?',
                          '반려',
                          const Color(0xFFFF3B30),
                        );
                        if (confirmed == true) {
                          await provider.updateLeaveStatus(l['id'], 'rejected');
                        }
                      },
                      child: const Text(
                        '반려',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [AppShadows.button],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await _showConfirmationDialog(
                          context,
                          '승인 확인',
                          '$name님의 $typeLabel 신청을 승인하시겠습니까?',
                          '승인',
                          const Color(0xFF34C759),
                        );
                        if (confirmed == true) {
                          await provider.updateLeaveStatus(l['id'], 'approved');
                        }
                      },
                      child: const Text(
                        '승인',
                        style: TextStyle(
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, color: const Color(0xFFFFA726), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '승인 권한이 없습니다',
                    style: TextStyle(
                      color: Color(0xFFFFA726),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!showButtons) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: status == 'approved' 
                    ? const Color(0xFF34C759).withOpacity(0.12) 
                    : const Color(0xFFFF3B30).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status == 'approved' ? '승인 완료' : '반려',
                style: TextStyle(
                  color: status == 'approved' 
                      ? const Color(0xFF34C759) 
                      : const Color(0xFFFF3B30),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFB0B0B0), size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF888888))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    String label;
    if (status == 'approved') {
      bg = const Color(0xFF34C759).withOpacity(0.12);
      fg = const Color(0xFF34C759);
      label = '승인';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFF3B30).withOpacity(0.12);
      fg = const Color(0xFFFF3B30);
      label = '반려';
    } else {
      bg = const Color(0xFFFFA726).withOpacity(0.12);
      fg = const Color(0xFFFFA726);
      label = '대기';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
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
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F7),
                      foregroundColor: const Color(0xFF1C1C1E),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
