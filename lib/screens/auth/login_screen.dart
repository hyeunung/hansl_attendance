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
import '../../utils/error_translator.dart';
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
    final newAutoLogin = prefs.getBool('autoLogin') ?? false;
    final newSaveId = prefs.getBool('saveId') ?? false;
    String? savedId;
    if (newSaveId) {
      savedId = prefs.getString('savedId') ?? '';
    }
    
    // 값이 변경되었을 때만 setState 호출
    if (mounted && (newAutoLogin != _autoLogin || newSaveId != _saveId || 
        (savedId != null && savedId.isNotEmpty && savedId != _emailController.text))) {
      setState(() {
        _autoLogin = newAutoLogin;
        _saveId = newSaveId;
        if (savedId != null && savedId.isNotEmpty) {
          _emailController.text = savedId;
        }
      });
    }
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
          // 페이드 효과만 사용하여 깜빡임 최소화
          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ));
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _login() async {
    // 상태 변경을 한 번에 처리
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      // 입력된 이메일을 그대로 사용
      final email = _emailController.text.trim();

      // Debug code removed

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

      // Debug code removed

      if (response.user != null) {
        // 직원 정보 employees 테이블에서 조회
        final email = response.user!.email;
        // Debug print removed
if (email == null) throw Exception('이메일 정보가 없습니다.');
        final employee = await Supabase.instance.client
            .from('employees')
            .select()
            .ilike('email', email) // 대소문자 무시하고 이메일 매칭
            .maybeSingle();

        // Debug code removed
        if (employee != null) {
          // Debug print removed
}

        if (employee == null) throw Exception('등록된 사용자 정보가 없습니다.');

        // UserProvider에 사용자 정보와 직원 정보 모두 설정
        if (!context.mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(
          id: employee['id'],
          name: employee['name'],
          email: employee['email'],
        );
        userProvider.setEmployee(employee);

        // Debug print removed
// Debug print removed
// Debug print removed
// Debug print removed
// 세션 지속성 확인 (사용되지 않는 변수 제거)
        // final currentSession = Supabase.instance.client.auth.currentSession;
        // Debug code removed

        // 자동 로그인 설정 저장 (보안상 비밀번호는 저장하지 않음)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('autoLogin', _autoLogin);

        if (_saveId) {
          // 이메일 주소 저장
          await prefs.setString('savedId', _emailController.text.trim());
        }

        // Debug print removed
_navigateWithTransition(MainTab());
        NotificationService.refreshTokenAfterLogin();
      } else {
        if (mounted) {
          setState(() {
            _error = ErrorTranslator.getUserFriendlyMessage('로그인 실패: 알 수 없는 오류');
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorTranslator.getUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
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
                        // Debug print removed
setState(
                          () => errorMsg =
                              ErrorTranslator.getUserFriendlyMessage(e),
                        );
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
                          // 바로 저장하지 않고 로그인 시에만 저장
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
                              if (value != null && value != _autoLogin) {
                                setState(() {
                                  _autoLogin = value;
                                });
                              }
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
                              if (value != null && value != _saveId) {
                                setState(() {
                                  _saveId = value;
                                });
                                _saveIdPref(value);
                              }
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
          _error = ErrorTranslator.getUserFriendlyMessage('회원가입 실패: 알 수 없는 오류');
        });
      }
    } catch (e) {
      setState(() {
        _error = ErrorTranslator.getUserFriendlyMessage(e);
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
