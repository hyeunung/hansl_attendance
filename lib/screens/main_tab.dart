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
  final PageController _pageController = PageController();
  final List<Widget> _screens = const [
    AttendanceScreen(),
    LeaveStatusScreen(),
    ApprovalScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(index, duration: Duration(milliseconds: 200), curve: Curves.ease);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _screens,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        physics: const BouncingScrollPhysics(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
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