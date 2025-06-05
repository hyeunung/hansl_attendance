import 'package:flutter/material.dart';
import 'attendance/attendance_screen.dart';
import 'leave/leave_status_screen.dart';
import 'approval/approval_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import '../theme/app_colors.dart'; 
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class MainTab extends StatefulWidget {
  final int initialIndex;
  const MainTab({super.key, this.initialIndex = 0});

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

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
    final userProvider = Provider.of<UserProvider>(context);
    final employee = userProvider.employee;
    final List<dynamic> purchaseRoles = (employee?['purchase_role'] as List<dynamic>?) ?? [];
    bool hasPurchaseRole(String role) => purchaseRoles.contains(role);
    final showPurchaseApprovalTab = hasPurchaseRole('middle_manager') || hasPurchaseRole('final_approver') || hasPurchaseRole('app_admin') || hasPurchaseRole('superadmin');
    final List<Widget> screens = [
      const AttendanceScreen(),
      const LeaveStatusScreen(),
      if (showPurchaseApprovalTab) const ApprovalScreen(),
      const CalendarScreen(),
      const SettingsScreen(),
    ];
    final List<BottomNavigationBarItem> items = [
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
      if (showPurchaseApprovalTab)
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.check_circle,
              color: _currentIndex == 2 ? const Color(0xFF34C759) : Colors.grey,
            ),
          ),
          label: '승인',
        ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            Icons.calendar_today,
            color: _currentIndex == (showPurchaseApprovalTab ? 3 : 2) ? const Color(0xFFFF3B30) : Colors.grey,
          ),
        ),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            Icons.settings,
            color: _currentIndex == (showPurchaseApprovalTab ? 4 : 3) ? const Color(0xFF8E8E93) : Colors.grey,
          ),
        ),
        label: '',
      ),
    ];
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: screens,
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
          color: Colors.white,
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 14,
          unselectedFontSize: 14,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          selectedIconTheme: const IconThemeData(size: 32),
          unselectedIconTheme: const IconThemeData(size: 32),
          items: items,
        ),
      ),
    );
  }
} 