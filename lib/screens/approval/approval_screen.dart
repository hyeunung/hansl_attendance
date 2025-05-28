import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_shadows.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '승인 관리',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E90FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          final allLeaves = provider.allLeaves;
          final pending = allLeaves.where((l) => l['status'] == 'pending').toList();
          final done = allLeaves.where((l) => l['status'] != 'pending').toList();
          final thisMonth = DateTime.now().month;
          final thisMonthDone = done.where((l) => DateTime.parse(l['created_at']).month == thisMonth).toList();
          
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
                    color: const Color(0xFF1E90FF),
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
                                  ...pending.map((l) => _approvalCard(context, l, provider)).toList(),
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
                                  ...done.map((l) => _approvalCard(context, l, provider, showButtons: false)).toList(),
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
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 28,
                color: Color(0xFF1E90FF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvalCard(BuildContext context, Map<String, dynamic> l, LeaveProvider provider, {bool showButtons = true}) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF2F2F7),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Details
          _detailRow('기간', period),
          if (isBiztrip && dest.isNotEmpty) _detailRow('목적지', dest),
          _detailRow('신청일', createdAt),
          
          const SizedBox(height: 12),
          
          // Reason
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reason,
              style: const TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          
          if (showButtons && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      // Show confirmation dialog
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
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34C759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      // Show confirmation dialog
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
              ],
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
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