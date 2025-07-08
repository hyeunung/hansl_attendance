import 'package:flutter/material.dart';
import '../auth/login_screen.dart'; // 또는 MainTab 등
import 'package:shared_preferences/shared_preferences.dart';
import '../main_tab.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

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
    });

    // 자동로그인 체크
    _checkAutoLogin();

    // 애니메이션이 끝난 뒤 3초 후에 다음 화면으로 이동
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            final autoLogin = prefs.getBool('autoLogin') ?? false;
            if (autoLogin) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainTab()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          }
        });
      }
    });
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool('autoLogin') ?? false;
    if (autoLogin) {
      final email = prefs.getString('autoLoginEmail');
      if (email != null && email.isNotEmpty) {
        final employee = await Supabase.instance.client
            .from('employees')
            .select()
            .eq('email', email)
            .maybeSingle();
        if (employee != null) {
          Provider.of<UserProvider>(context, listen: false).setUser(
            id: employee['id'],
            name: employee['name'],
            email: employee['email'],
          );
        }
      }
      // Splash 애니메이션 끝나면 MainTab으로 이동하도록 위에서 처리
    }
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
            children: const [
              Text(
                'HANSL',
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w800,
                  fontSize: 44,
                  color: AppColors.primary,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      offset: Offset(0.5, 1),
                      blurRadius: 3,
                      color: Color.fromRGBO(0, 0, 0, 0.2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4),
              Text(
                '근태 기록 시스템',
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w400,
                  fontSize: 17,
                  color: Color(0xFFB0B8C1),
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      offset: Offset(0.5, 1),
                      blurRadius: 3,
                      color: Color.fromRGBO(0, 0, 0, 0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
