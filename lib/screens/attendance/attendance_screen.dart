import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/user_provider.dart';
import 'dart:async';
import '../../models/attendance.dart';
import '../../theme/app_shadows.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return ChangeNotifierProvider(
          create: (_) {
            final userId = userProvider.id;
            final userName = userProvider.name;
            if (userId == null || userId.isEmpty) {
              throw Exception('UserProvider의 id가 null이거나 빈 문자열입니다. 로그인 로직을 확인하세요.');
            }
            return AttendanceProvider(
              userId: userId,
              userName: userName ?? '',
            );
          },
          child: _AttendanceScreenBody(),
        );
      },
    );
  }
}

class _AttendanceScreenBody extends StatefulWidget {
  @override
  State<_AttendanceScreenBody> createState() => _AttendanceScreenBodyState();
}

class _AttendanceScreenBodyState extends State<_AttendanceScreenBody> {
  String? _bannerMessage;
  Color _bannerColor = const Color(0xFF357AE8);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showBanner(String msg, {bool error = false}) {
    setState(() {
      _bannerMessage = msg;
      _bannerColor = error ? Colors.red : const Color(0xFF357AE8);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  Widget _buildBanner() {
    if (_bannerMessage == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: _bannerColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          _bannerMessage!,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  LinearGradient _getStatusGradient(String statusText) {
    switch (statusText) {
      case '지각':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)], // 빨강 그라데이션
        );
      case '정상 출근':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1777CB), Color(0xFF0D4F8C)], // 파랑 그라데이션
        );
      case '퇴근':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)], // 초록색 그라데이션
        );
      default: // 출근 전
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9E9E9E), Color(0xFF757575)], // 회색 그라데이션
        );
    }
  }

  Color _getStatusShadowColor(String statusText) {
    switch (statusText) {
      case '지각':
        return const Color(0xFFEE5A24).withOpacity(0.3);
      case '정상 출근':
        return const Color(0xFF0D4F8C).withOpacity(0.3);
      case '퇴근':
        return const Color(0xFF45A049).withOpacity(0.3);
      default:
        return const Color(0xFF757575).withOpacity(0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x332196F3),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            title: const Text(
              'HANSL 근무 기록',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Consumer<UserProvider>(
                  builder: (context, userProvider, _) {
                    final name = userProvider.name ?? '-';
                    return Center(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 현재 상태 카드
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [AppShadows.card],
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '현재 상태',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w600,
                                fontSize: 24,
                                color: Color(0xFF343A40),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _getStatusGradient(provider.statusText),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusShadowColor(provider.statusText),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                provider.statusText,
                                style: const TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              provider.clockInTime == null
                                  ? '-'
                                  : '${provider.clockInStr} 부터',
                              style: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF6C757D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 25),
                      // 출근/퇴근 버튼 (흰카드 없이 Row만)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 65,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.status == AttendanceStatus.beforeWork
                                      ? AppColors.primary
                                      : const Color(0xFFE9ECEF),
                                  foregroundColor: provider.status == AttendanceStatus.beforeWork
                                      ? Colors.white
                                      : const Color(0xFFB0B0B0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: provider.status == AttendanceStatus.beforeWork ? 6 : 0,
                                  shadowColor: Colors.black,
                                ),
                                onPressed: provider.status == AttendanceStatus.beforeWork
                                    ? () async {
                                        await provider.tryClockIn();
                                        if (provider.errorMessage != null) {
                                          _showBanner(provider.errorMessage!, error: true);
                                          provider.clearError();
                                        }
                                      }
                                    : null,
                                child: Text(
                                  '출근하기',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: SizedBox(
                              height: 65,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.canClockOut
                                      ? AppColors.primary
                                      : const Color(0xFFE9ECEF),
                                  foregroundColor: provider.canClockOut
                                      ? Colors.white
                                      : const Color(0xFFB0B0B0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: provider.canClockOut ? 6 : 0,
                                  shadowColor: Colors.black,
                                ),
                                onPressed: provider.canClockOut
                                    ? () async {
                                        await provider.tryClockOut();
                                      }
                                    : null,
                                child: Text(
                                  '퇴근하기',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 25),
                      // 오늘의 근무 요약 카드
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [AppShadows.card],
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  child: const Text(
                                    '💼',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  '오늘의 근무 요약',
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildSummaryItem('출근 시간', provider.clockInStr),
                            _buildSummaryItem('근무 시간', provider.todayWorkDuration, isLast: true),
                          ],
                        ),
                      ),
                      SizedBox(height: 25),
                      // 최근 기록 카드
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [AppShadows.card],
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  child: const Text(
                                    '⏱️',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  '최근 기록',
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            provider.recentHistory.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '아직 기록이 없습니다',
                                      style: TextStyle(
                                        fontFamily: 'NotoSans',
                                        color: Color(0xFF6C757D),
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: provider.recentHistory.map((record) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: _buildHistoryRow(record),
                                    )).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 17,
                color: Color(0xFF6C757D),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF343A40),
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: const Color(0xFFF1F3F4),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  static Widget _buildHistoryRow(AttendanceRecord record) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Color(0xFF444444),
            ),
          ),
          Text(
            '출근: ${record.clockIn == null ? '-' : _formatTime(record.clockIn!)}',
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}