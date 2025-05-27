import 'package:flutter/material.dart';
import 'attendance/attendance_screen.dart';
import 'leave/leave_status_screen.dart';
import 'approval/approval_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import '../theme/app_colors.dart'; 

class MainTab extends StatefulWidget {
  const MainTab({super.key});

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    AttendanceScreen(),
    LeaveStatusScreen(),
    ApprovalScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary, // 메인 컬러(파랑)
        unselectedItemColor: Colors.grey,     // 비선택 탭(회색)
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: '출퇴근'),
          BottomNavigationBarItem(icon: Icon(Icons.beach_access), label: '연차/출장'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: '승인'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '달력'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
} 