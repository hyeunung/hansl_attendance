import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import 'annual_leave_request_screen.dart';
import 'business_trip_request_screen.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

class LeaveStatusScreen extends StatefulWidget {
  const LeaveStatusScreen({super.key});

  @override
  State<LeaveStatusScreen> createState() => _LeaveStatusScreenState();
}

class _LeaveStatusScreenState extends State<LeaveStatusScreen> {
  int _selectedTab = 0; // 0: 연차, 1: 출장
  final double rValue = 14;

  @override
  void initState() {
    super.initState();
    // build 완료 후에 비동기적으로 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
    final provider = Provider.of<LeaveProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.email != null && userProvider.email!.isNotEmpty) {
      provider.fetchMyLeaves(email: userProvider.email!);
    }
    provider.fetchTodayLeaves(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = Provider.of<UserProvider>(context, listen: false).email;
    print('userProvider.email: $userEmail');
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
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
            '연차/출장 대시보드',
            style: AppTextStyles.appBarTitle(context),
          ),
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          print('myLeaves: ' + provider.myLeaves.toString());
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text('에러: ${provider.error}'));
          }
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 20), 
              vertical: ResponsiveUtils.spacing(context, 20)
            ),
            children: [
              // 1. 내 연차 현황 - 애플 스타일
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 28)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
                  boxShadow: [AppShadows.card],
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                    ),
                child: Column(
                  children: [
                    // 제목 - 아이콘과 함께
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 6)),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: const Color(0xFF007AFF),
                            size: ResponsiveUtils.iconSize(context, 16),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        Text(
                          '내 연차 현황',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: const Color(0xFF1D1D1F),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                    
                    // 메인 잔여 연차
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 20)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            provider.remainAnnual.toString(),
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.w700,
                              fontSize: 36,
                              color: const Color(0xFF007AFF),
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                          Text(
                            '잔여 연차',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFF5A6C7D),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                    
                    // 서브 정보들
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.spacing(context, 16), 
                              horizontal: ResponsiveUtils.spacing(context, 16)
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2E6),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  provider.pendingCount.toString(),
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: const Color(0xFFFF9500),
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                                Text(
                                  '대기 중',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: const Color(0xFF8D6E63),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                        
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.spacing(context, 16), 
                              horizontal: ResponsiveUtils.spacing(context, 16)
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7E6),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  provider.biztripDays.toString(),
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: const Color(0xFF34C759),
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                                Text(
                                  '출장 일수',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: const Color(0xFF2E7D32),
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
              SizedBox(height: ResponsiveUtils.spacing(context, 25)),
              // 2. 연차/출장 신청 버튼 (흰색 박스 안에 좌우로)
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 0)),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: ResponsiveUtils.spacing(context, 65),
                            child: _mainTabButton('연차 신청', 0, ResponsiveUtils.spacing(context, rValue)),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 15)),
                        Expanded(
                          child: SizedBox(
                            height: ResponsiveUtils.spacing(context, 65),
                            child: _mainTabButton('출장 신청', 1, ResponsiveUtils.spacing(context, rValue)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 25)),
              // 3. 최근 신청
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, rValue)),
                  boxShadow: [AppShadows.card],
                ),
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.spacing(context, 18), 
                  horizontal: ResponsiveUtils.spacing(context, 18)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('최근 신청', style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.w800, fontSize: 25, color: const Color(0xFF222222), letterSpacing: 0.1, height: 1.25)),
                    SizedBox(height: ResponsiveUtils.spacing(context, 10)),
                    if (provider.recentLeaves.isEmpty)
                      Text('최근 신청 내역이 없습니다.', style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.w400, fontSize: 14, color: const Color(0xFFAAAAAA), letterSpacing: 0.1, height: 1.2)),
                    Divider(height: ResponsiveUtils.spacing(context, 18), thickness: 2, color: const Color(0xFFE0E3E8)),
                    ..._recentLeaveWithAllDividers(provider.recentLeaves),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 22)),
              // 4. 오늘자 연차/출장 직원 현황 (흰색 박스 + 내용만 회색 박스)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, rValue)),
                  boxShadow: [AppShadows.card],
                ),
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연차/출장 현황', style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.w700, fontSize: 23, color: const Color(0xFF222222), letterSpacing: 0.1, height: 1.25)),
                        Text(
                          DateTime.now().toString().substring(0, 10).replaceAll('-', '.'),
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: const Color(0xFF888888),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F7),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, rValue)),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 16), 
                        vertical: ResponsiveUtils.spacing(context, 14)
                      ),
                      child: provider.todayLeaves.isEmpty
                        ? Text(
                            '오늘자 연차/출장 직원이 없습니다.',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.w400,
                              fontSize: 17,
                              color: const Color(0xFFAAAAAA),
                              letterSpacing: 0.1,
                              height: 1.2,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...provider.todayLeaves.map((l) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(l['type'] == 'biztrip' ? Icons.flight_takeoff : Icons.beach_access, size: 20, color: l['type'] == 'biztrip' ? AppColors.primary : Color(0xFFFFA726)),
                                    const SizedBox(width: 10),
                                    Text(l['name'] ?? l['user_email'] ?? '-', style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 19,
                                      color: const Color(0xFF222222),
                                      letterSpacing: 0.1,
                                      height: 1.25,
                                    )),
                                    const SizedBox(width: 8),
                                    _leaveTypeChip(l['type']),
                                  ],
                                ),
                              )),
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

  Widget _statusBox(String label, String value) {
    return Container(
      height: ResponsiveUtils.spacing(context, 40),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 18), 
        vertical: ResponsiveUtils.spacing(context, 8)
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 25)),
        boxShadow: [AppShadows.card],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: const Color(0xFF357AE8),
            ),
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 2)),
          Text(
            label,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: const Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainTabButton(String label, int idx, double r) {
    final isAnnual = idx == 0;
    return SizedBox(
      height: ResponsiveUtils.spacing(context, 54),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = idx);
          if (idx == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnualLeaveRequestScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessTripRequestScreen()));
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isAnnual ? AppColors.primaryGradient : null,
            color: isAnnual ? null : Colors.white,
            borderRadius: BorderRadius.circular(r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.36),
                blurRadius: ResponsiveUtils.spacing(context, 6),
                offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.w700,
              fontSize: 21,
              letterSpacing: 0.1,
              height: 1.2,
              color: isAnnual ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'annual':
        return AppColors.primary; // 연파랑 배경엔 진한 파랑
      case 'half_am':
        return const Color(0xFFFFE0B2); // 연주황
      case 'half_pm':
        return const Color(0xFFC8E6C9); // 연초록
      case 'official':
        return const Color(0xFFE0E0E0); // 연회색
      default:
        return Colors.black12;
    }
  }

  Color _chipTextColor(String type) {
    switch (type) {
      case 'annual':
        return AppColors.primary; // 연파랑 배경엔 진한 파랑
      case 'half_am':
        return const Color(0xFFFF9800); // 연주황 배경엔 진한 주황
      case 'half_pm':
        return const Color(0xFF388E3C); // 연초록 배경엔 진한 초록
      case 'official':
        return const Color(0xFF757575); // 연회색 배경엔 진한 회색
      default:
        return Colors.black87;
    }
  }

  Widget _recentLeaveTile(Map<String, dynamic> l) {
    String typeLabel = l['type'] == 'biztrip' ? '출장 신청' : '연차 신청';
    String typeDetail = '';
    switch (l['type']) {
      case 'annual': typeDetail = '연차'; break;
      case 'half_am': typeDetail = '오전반차'; break;
      case 'half_pm': typeDetail = '오후반차'; break;
      case 'official': typeDetail = '공가'; break;
      default: typeDetail = '';
    }
    String status = l['status'] ?? '';
    DateTime start = DateTime.parse(l['start_date']);
    DateTime end = DateTime.parse(l['end_date']);
    int days = end.difference(start).inDays + 1;
    double displayDays = 1.0 * days;
    if (l['type'] == 'halfAm' || l['type'] == 'half_am' || l['type'] == 'halfPm' || l['type'] == 'half_pm') {
      displayDays = 0.5;
    }
    String period = '';
    if (start.month == end.month) {
      period = '${start.month}월 ${start.day}일 - ${end.day}일 (${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
    } else {
      period = '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일 (${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
    }
    String? companions = l['companions'];
    String? reason = l['reason'];
    String statusLabel = status == 'approved' ? '승인됨' : status == 'pending' ? '대기중' : '반려';
    Color statusColor = status == 'approved' ? Color(0xFF4CAF50) : status == 'pending' ? Color(0xFFFFA726) : Color(0xFFE57373);
    final String name = l['type'] == 'biztrip' ? (l['name'] ?? '-') : '';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(l['type'] == 'biztrip' ? Icons.flight_takeoff : Icons.beach_access, size: 20, color: l['type'] == 'biztrip' ? AppColors.primary : Color(0xFFFFA726)),
              const SizedBox(width: 10),
              Text(l['name'] ?? l['user_email'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF222222))),
              const SizedBox(width: 8),
              _leaveTypeChip(l['type']),
              Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(period, style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
            if (companions != null && companions.isNotEmpty)
              Text(' ($companions 동행)', style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
          ],
        ),
      ],
    );
  }

  List<Widget> _recentLeaveWithAllDividers(List<Map<String, dynamic>> leaves) {
    final List<Widget> widgets = [];
    for (int i = 0; i < leaves.length; i++) {
      widgets.add(_recentLeaveTile(leaves[i]));
      widgets.add(const Divider(height: 18, thickness: 2, color: Color(0xFFE0E3E8)));
    }
    return widgets;
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.month}/${now.day}';
  }

  Widget _leaveTypeChip(String type) {
    String label;
    Color bgColor;
    Color textColor;
    final normalizedType = type.toLowerCase().replaceAll('_', '');
    switch (normalizedType) {
      case 'annual':
        label = '연차';
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
        break;
      case 'halfam':
        label = '오전반차';
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        break;
      case 'halfpm':
        label = '오후반차';
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF388E3C);
        break;
      case 'official':
        label = '공가';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF757575);
        break;
      case 'biztrip':
        label = '출장';
        bgColor = const Color(0xFFF3E5F5); // 보라색 배경
        textColor = const Color(0xFF7B1FA2); // 보라색 글자
        break;
      default:
        label = type;
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
    }
    return Container(
      margin: EdgeInsets.only(left: ResponsiveUtils.spacing(context, 8)),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 12), 
        vertical: ResponsiveUtils.spacing(context, 5)
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
      ),
      child: Text(
        label,
        style: ResponsiveUtils.getTextStyle(
          context,
          color: textColor.withOpacity(0.8),
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

 