import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/responsive_utils.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  const LoginScreen({super.key, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _autoLogin = false;
  bool _saveId = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoLogin = prefs.getBool('autoLogin') ?? false;
      _saveId = prefs.getBool('saveId') ?? false;
      if (_saveId) {
        final savedId = prefs.getString('savedId') ?? '';
        if (savedId.isNotEmpty) {
          _emailController.text = savedId;
        }
      }
      // 자동로그인은 Supabase 세션에서 처리하므로 여기서는 제거
    });
  }

  Future<void> _saveIdPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('saveId', value);
    if (value) {
      // 이메일 주소 저장
      await prefs.setString('savedId', _emailController.text.trim());
    } else {
      await prefs.remove('savedId');
    }
  }

  void _navigateWithTransition(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 입력된 이메일을 그대로 사용
      final email = _emailController.text.trim();

      print('🔐 로그인 시도 중... 이메일: $email');
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

      print('📱 로그인 응답: ${response.user != null ? "성공" : "실패"}');
      print('📱 세션 정보: ${response.session != null ? "존재함" : "없음"}');

      if (response.user != null) {
        // 직원 정보 employees 테이블에서 조회
        final email = response.user!.email;
        print('📧 응답 이메일: $email');

        if (email == null) throw Exception('이메일 정보가 없습니다.');
        final employee = await Supabase.instance.client
            .from('employees')
            .select()
            .ilike('email', email) // 대소문자 무시하고 이메일 매칭
            .maybeSingle();

        print('👤 직원 정보 조회 결과: ${employee != null ? "찾음" : "없음"}');
        if (employee != null) {
          print('👤 직원 데이터: $employee');
        }

        if (employee == null) throw Exception('등록된 사용자 정보가 없습니다.');

        // UserProvider에 사용자 정보와 직원 정보 모두 설정
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(
          id: employee['id'],
          name: employee['name'],
          email: employee['email'],
        );
        userProvider.setEmployee(employee);

        print('✅ UserProvider 설정 완료');
        print('👤 저장된 ID: ${userProvider.id}');
        print('👤 저장된 이름: ${userProvider.name}');
        print('👤 저장된 이메일: ${userProvider.email}');

        // 세션 지속성 확인
        final currentSession = Supabase.instance.client.auth.currentSession;
        print('🔒 현재 세션 상태: ${currentSession != null ? "유지됨" : "없음"}');

        // 자동 로그인 설정 저장 (보안상 비밀번호는 저장하지 않음)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('autoLogin', _autoLogin);

        if (_saveId) {
          // 이메일 주소 저장
          await prefs.setString('savedId', _emailController.text.trim());
        }

        print('✅ 로그인 완료 - 메인 화면으로 이동');
        _navigateWithTransition(const MainTab());
        NotificationService.refreshTokenAfterLogin();
      } else {
        setState(() {
          _error = '로그인 실패: 알 수 없는 오류';
        });
      }
    } catch (e) {
      setState(() {
        _error = '로그인 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    String? errorMsg;
    bool sent = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('비밀번호 재설정'),
              content: sent
                  ? const Text('비밀번호 재설정 메일을 전송했습니다. 메일함을 확인해주세요.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            hintText: '이메일 주소 입력',
                          ),
                        ),
                        if (errorMsg != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorMsg!,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
              actions: [
                if (!sent)
                  TextButton(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        setState(() => errorMsg = '이메일을 입력하세요.');
                        return;
                      }
                      // 입력된 이메일을 그대로 사용
                      try {
                        await Supabase.instance.client.auth
                            .resetPasswordForEmail(
                              email,
                              redirectTo:
                                  'com.hansl.attendance.v2://reset-password',
                            );
                        setState(() {
                          sent = true;
                          errorMsg = null;
                        });
                      } catch (e) {
                        print('Password reset error: $e');
                        setState(() => errorMsg = '메일 전송 실패: ${e.toString()}');
                      }
                    },
                    child: const Text('메일 전송'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final boxRadius = BorderRadius.circular(8);
    final fieldRadius = BorderRadius.circular(8);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: kIsWeb
            ? null
            : (Platform.isAndroid ? BackButton(color: Colors.black) : null),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: ResponsiveUtils.spacing(context, 32)),
                Text('HANSL', style: ResponsiveTextStyles.logoTitle(context)),
                SizedBox(height: ResponsiveUtils.spacing(context, 10)),
                Text(
                  '근태 기록 시스템',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFB0B8C1),
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 40)),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: '이메일',
                          labelStyle: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                          hintText: '이메일 주소 입력',
                          hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                          filled: true,
                          fillColor: Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: fieldRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        enableSuggestions: true,
                        autocorrect: false,
                        onChanged: (val) {
                          if (_saveId) _saveIdPref(true);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          labelStyle: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                          hintText: '비밀번호 입력',
                          hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                          filled: true,
                          fillColor: Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: fieldRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _autoLogin,
                            onChanged: (value) {
                              setState(() {
                                _autoLogin = value ?? false;
                              });
                            },
                          ),
                          Text(
                            '자동 로그인',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 15,
                              color: const Color(0xFF222222),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Checkbox(
                            value: _saveId,
                            onChanged: (value) {
                              setState(() {
                                _saveId = value ?? false;
                              });
                              _saveIdPref(value ?? false);
                            },
                          ),
                          Text(
                            '아이디 저장',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 15,
                              color: const Color(0xFF222222),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
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
                      else ...[
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1777CB),
                              shape: RoundedRectangleBorder(
                                borderRadius: boxRadius,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: Text(
                              '로그인',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                if (Platform.isIOS) {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) => SignupScreen(
                                        onSignupSuccess: (email) {},
                                      ),
                                    ),
                                  );
                                } else {
                                  _navigateWithTransition(
                                    SignupScreen(onSignupSuccess: (email) {}),
                                  );
                                }
                              },
                              child: const Text(
                                '회원가입',
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: Color(0xFF1777CB),
                                ),
                              ),
                            ),
                            const Text(
                              '|',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFB0B8C1),
                              ),
                            ),
                            TextButton(
                              onPressed: _showResetPasswordDialog,
                              child: const Text(
                                '비밀번호 재설정',
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: Color(0xFF1777CB),
                                ),
                              ),
                            ),
                          ],
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
}

class SignupScreen extends StatefulWidget {
  final void Function(String email) onSignupSuccess;
  const SignupScreen({super.key, required this.onSignupSuccess});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _error = '이름을 입력하세요.';
        _isLoading = false;
      });
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() {
        _error = '비밀번호가 일치하지 않습니다.';
        _isLoading = false;
      });
      return;
    }
    try {
      // 입력된 이메일을 소문자로 변환하고 공백 제거
      final email = _emailController.text.trim().toLowerCase();

      // 먼저 employees 테이블에 해당 이메일이 있는지 확인
      final existingEmployee = await Supabase.instance.client
          .from('employees')
          .select()
          .ilike('email', email) // 대소문자 무시
          .maybeSingle();

      if (existingEmployee == null) {
        setState(() {
          _error = '등록된 직원이 아닙니다. 관리자에게 문의하세요.';
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {'display_name': _nameController.text.trim()},
      );
      if (response.user != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인 해주세요.')),
        );
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LoginScreen(initialEmail: _emailController.text.trim()),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(-1.0, 0.0); // 왼쪽에서 슬라이드
                  const end = Offset.zero;
                  const curve = Curves.ease;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: FadeTransition(
                      opacity: animation.drive(fadeTween),
                      child: child,
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
        return;
      } else {
        setState(() {
          _error = '회원가입 실패: 알 수 없는 오류';
        });
      }
    } catch (e) {
      String msg = '회원가입 실패: $e';
      if (e.toString().contains('user_already_exists') ||
          e.toString().contains('already registered')) {
        msg = '이미 가입된 이메일입니다. 로그인 해주세요.';
      }
      setState(() {
        _error = msg;
      });
    } finally {
      setState(() {
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Text(
                  'HANSL',
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    color: Color(0xFF1777CB),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '근태 기록 시스템',
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: Color(0xFFB0B8C1),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: '이름',
                          labelStyle: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                          filled: true,
                          fillColor: Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: fieldRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: '이메일',
                          labelStyle: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                          hintText: '이메일 주소 입력',
                          hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                          filled: true,
                          fillColor: Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: fieldRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        enableSuggestions: true,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          labelStyle: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                          hintText: '비밀번호 입력',
                          hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                          filled: true,
                          fillColor: Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: fieldRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordConfirmController,
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: '비밀번호 확인',
                          labelStyle: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                          hintText: '비밀번호 확인',
                          hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                          filled: true,
                          fillColor: Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: fieldRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                        obscureText: true,
                      ),
                      if (_error != null) ...[
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
                      else ...[
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1777CB),
                              shape: RoundedRectangleBorder(
                                borderRadius: boxRadius,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: Text(
                              '회원가입 완료',
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
}
