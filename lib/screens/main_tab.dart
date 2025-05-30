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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
          ),
          color: Colors.white, // 완전 흰색
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white, // 내부 배경도 완전 흰색
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 14,
          unselectedFontSize: 14,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          selectedIconTheme: const IconThemeData(size: 32),
          unselectedIconTheme: const IconThemeData(size: 32),
          items: [
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Icon(
                  Icons.access_time,
                  color: _currentIndex == 0 ? const Color(0xFFFF9500) : Colors.grey,
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Icon(
                  Icons.beach_access,
                  color: _currentIndex == 1 ? AppColors.primary : Colors.grey,
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Icon(
                  Icons.check_circle,
                  color: _currentIndex == 2 ? const Color(0xFF34C759) : Colors.grey,
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Icon(
                  Icons.calendar_today,
                  color: _currentIndex == 3 ? const Color(0xFFFF3B30) : Colors.grey,
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Icon(
                  Icons.settings,
                  color: _currentIndex == 4 ? const Color(0xFF8E8E93) : Colors.grey,
                ),
              ),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
} 