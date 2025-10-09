import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
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
                  fontWeight: FontWeight.w600,
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
                '근태기록시스템',
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
            ],
          ),
        ),
      ),
    );
  }
}
