import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/error_translator.dart';
import '../../utils/responsive_utils.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    // URL에서 토큰 확인
    _checkAccessToken();
  }

  Future<void> _checkAccessToken() async {
    // Supabase가 자동으로 처리하므로 세션 확인만
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() {
        _error = '유효하지 않은 링크입니다. 비밀번호 재설정을 다시 요청해주세요.';
      });
    }
  }

  Future<void> _resetPassword() async {
    // 비밀번호 확인
    if (_passwordController.text.isEmpty) {
      setState(() => _error = '새 비밀번호를 입력해주세요.');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _error = '비밀번호는 최소 6자 이상이어야 합니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 새 비밀번호로 업데이트
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (response.user != null) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });

        // 성공 메시지 표시 후 로그인 화면으로 이동
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('비밀번호가 성공적으로 변경되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );

          // 로그아웃 후 로그인 화면으로 이동
          await Supabase.instance.client.auth.signOut();
          
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = ErrorTranslator.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxRadius = BorderRadius.circular(8);
    final fieldRadius = BorderRadius.circular(8);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Text(
                  'HANSL',
                  style: ResponsiveTextStyles.logoTitle(context),
                ),
                const SizedBox(height: 10),
                Text(
                  '비밀번호 재설정',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: ResponsiveUtils.spacing(context, 340),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacing(context, 20),
                    vertical: ResponsiveUtils.spacing(context, 28),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: boxRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isSuccess
                      ? Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '비밀번호가 변경되었습니다',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '잠시 후 로그인 화면으로 이동합니다',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 14,
                                color: const Color(0xFF666666),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null &&
                                _error!.contains('유효하지 않은 링크')) ...[
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  color: const Color(0xFFE53935),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1777CB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: boxRadius,
                                  ),
                                ),
                                child: Text(
                                  '로그인 화면으로',
                                  style: ResponsiveUtils.getTextStyle(context, fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ] else ...[
                              Text(
                                '새로운 비밀번호를 입력해주세요',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: '새 비밀번호',
                                  labelStyle: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: Color(0xFF222222),
                                  ),
                                  hintText: '6자 이상 입력',
                                  hintStyle: ResponsiveUtils.getTextStyle(context, fontSize: 14, color: Color(0xFFB0B8C1)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FA),
                                  border: OutlineInputBorder(
                                    borderRadius: fieldRadius,
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _confirmPasswordController,
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: '비밀번호 확인',
                                  labelStyle: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: Color(0xFF222222),
                                  ),
                                  hintText: '비밀번호 재입력',
                                  hintStyle:
                                      ResponsiveUtils.getTextStyle(context, fontSize: 14, color: Color(0xFFB0B8C1)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FA),
                                  border: OutlineInputBorder(
                                    borderRadius: fieldRadius,
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                obscureText: true,
                              ),
                              if (_error != null &&
                                  !_error!.contains('유효하지 않은 링크')) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    color: const Color(0xFFE53935),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (_isLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _resetPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1777CB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: boxRadius,
                                      ),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      '비밀번호 변경',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}