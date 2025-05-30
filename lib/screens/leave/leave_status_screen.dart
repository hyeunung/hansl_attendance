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
    final provider = Provider.of<LeaveProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.email != null && userProvider.email!.isNotEmpty) {
      provider.fetchMyLeaves(email: userProvider.email!);
    }
    provider.fetchTodayLeaves(DateTime.now());
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
        title: const Text(
          '연차/출장 대시보드',
          style: AppTextStyles.appBarTitle,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // 1. 내 연차 현황 - 애플 스타일
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [AppShadows.card],
                  border: Border.all(color: Color(0xFFE9ECEF)),
                ),
                child: Column(
                  children: [
                    // 제목 - 아이콘과 함께
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF007AFF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '내 연차 현황',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Color(0xFF1D1D1F),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 메인 잔여 연차
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            provider.remainAnnual.toString(),
                            style: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w700,
                              fontSize: 36,
                              color: Color(0xFF007AFF),
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '잔여 연차',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF5A6C7D),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 서브 정보들
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2E6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  provider.pendingCount.toString(),
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: Color(0xFFFF9500),
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '대기 중',
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF8D6E63),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7E6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  provider.biztripDays.toString(),
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: Color(0xFF34C759),
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '출장 일수',
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF2E7D32),
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
              const SizedBox(height: 25),
              // 2. 연차/출장 신청 버튼 (흰색 박스 안에 좌우로)
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 65,
                            child: _mainTabButton('연차 신청', 0, rValue),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: SizedBox(
                            height: 65,
                            child: _mainTabButton('출장 신청', 1, rValue),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 25),
              // 3. 최근 신청
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(rValue),
                  boxShadow: [AppShadows.card],
                ),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('최근 신청', style: _titleStyle),
                    const SizedBox(height: 10),
                    if (provider.recentLeaves.isEmpty)
                      const Text('최근 신청 내역이 없습니다.', style: _listDescStyle),
                    const Divider(height: 18, thickness: 2, color: Color(0xFFE0E3E8)),
                    ..._recentLeaveWithAllDividers(provider.recentLeaves),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // 4. 오늘자 연차/출장 직원 현황 (흰색 박스 + 내용만 회색 박스)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(rValue),
                  boxShadow: [AppShadows.card],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연차/출장 현황', style: _sectionTitleStyle),
                        Text(
                          DateTime.now().toString().substring(0, 10).replaceAll('-', '.'),
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: Color(0xFF888888),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F7),
                        borderRadius: BorderRadius.circular(rValue),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: provider.todayLeaves.isEmpty
                        ? const Text(
                            '오늘자 연차/출장 직원이 없습니다.',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                              fontSize: 17,
                              color: Color(0xFFAAAAAA),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(l['type'] == 'biztrip' ? Icons.flight_takeoff : Icons.beach_access, size: 20, color: l['type'] == 'biztrip' ? AppColors.primary : Color(0xFFFFA726)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(l['name'] ?? l['user_email'] ?? '-', style: _listTitleStyle),
                                              const SizedBox(width: 8),
                                              _leaveTypeChip(l['type']),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${l['start_date']}~${l['end_date']}',
                                            style: _listSubStyle,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [AppShadows.card],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: Color(0xFF357AE8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainTabButton(String label, int idx, double r) {
    final isAnnual = idx == 0;
    return SizedBox(
      height: 54,
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
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _mainButtonTextStyle.copyWith(
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
    // 오전/오후반차는 0.5일로 표시
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
    // 신청자 이름(leave DB의 name, 출장신청만 표시)
    final String name = l['type'] == 'biztrip' ? (l['name'] ?? '-') : '';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF222222))),
                        if (typeDetail.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _typeColor(l['type']).withOpacity(0.32),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              typeDetail,
                              style: TextStyle(
                                color: _chipTextColor(l['type']).withOpacity(0.8),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        // 신청자 이름(출장신청만, Chip 스타일)
                        if (name.isNotEmpty && name != '-')
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB3D8FF).withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color.fromRGBO(53, 122, 232, 0.6),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                      ],
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
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
        // Divider는 항목 사이에 직접 넣지 않음(타입이 바뀌는 곳만)
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
    switch (type) {
      case 'annual':
        label = '연차';
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
        break;
      case 'halfAm':
      case 'half_am':
        label = '오전반차';
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        break;
      case 'halfPm':
      case 'half_pm':
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
        bgColor = const Color(0xFFF3E5F5);
        textColor = const Color(0xFF7B1FA2);
        break;
      default:
        label = type;
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
    }
    return Container(
      margin: const EdgeInsets.only(left: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

const _titleStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w800,
  fontSize: 25,
  color: Color(0xFF222222),
  letterSpacing: 0.1,
  height: 1.25,
);
const _sectionTitleStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w700,
  fontSize: 23,
  color: Color(0xFF222222),
  letterSpacing: 0.1,
  height: 1.25,
);
const _statusLabelStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w800,
  fontSize: 19,
  color: Color(0xFF555A65),
  letterSpacing: 0.1,
  height: 1.25,
);
const _statusValueStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w800,
  fontSize: 32,
  color: Color(0xFF357AE8),
  letterSpacing: 0.1,
  height: 1.15,
);
const _mainButtonTextStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w700,
  fontSize: 21,
  letterSpacing: 0.1,
  height: 1.2,
);
const _badgeTextStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.bold,
  fontSize: 15,
  letterSpacing: 0.1,
  height: 1.2,
);
const _listTitleStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w700,
  fontSize: 19,
  color: Color(0xFF222222),
  letterSpacing: 0.1,
  height: 1.25,
);
const _listSubStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w400,
  fontSize: 15,
  color: Color(0xFF888888),
  letterSpacing: 0.1,
  height: 1.25,
);
const _listDescStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontWeight: FontWeight.w400,
  fontSize: 14,
  color: Color(0xFFAAAAAA),
  letterSpacing: 0.1,
  height: 1.2,
);