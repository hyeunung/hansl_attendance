import 'package:flutter/material.dart';
import '../auth/login_screen.dart'; // 또는 MainTab 등
import 'package:shared_preferences/shared_preferences.dart';
import '../main_tab.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/responsive_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // 0.4초 페이드인
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // 화면이 실제로 그려진 직후 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // 스플래시 표시 시간
    
    if (_isNavigating || !mounted) return;
    
    try {
      // 현재 Supabase 세션 확인
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null && session.user != null) {
        // 세션이 유효한 경우, 직원 정보 확인
        final email = session.user!.email;
        if (email != null) {
        final employee = await Supabase.instance.client
            .from('employees')
            .select()
            .eq('email', email)
            .maybeSingle();
              
        if (employee != null) {
            // UserProvider에 사용자 정보 설정
            if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(
            id: employee['id'],
            name: employee['name'],
            email: employee['email'],
          );
              _navigateToMainTab();
              return;
        }
      }
        }
      }
      
      // 세션이 없거나 유효하지 않은 경우 로그인 화면으로
      _navigateToLogin();
      
    } catch (e) {
      print('인증 상태 확인 중 오류: $e');
      _navigateToLogin();
    }
  }

  void _navigateToMainTab() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainTab()),
    );
  }

  void _navigateToLogin() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HANSL',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 4,
                ).copyWith(
                  shadows: const [
                    Shadow(
                      offset: Offset(0.5, 1),
                      blurRadius: 3,
                      color: Color.fromRGBO(0, 0, 0, 0.2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 4)),
              Text(
                '근태 기록 시스템',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFB0B8C1),
                  letterSpacing: 1.2,
                ).copyWith(
                  shadows: const [
                    Shadow(
                      offset: Offset(0.5, 1),
                      blurRadius: 3,
                      color: Color.fromRGBO(0, 0, 0, 0.2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
            ],
          ),
        ),
      ),
    );
  }
}
