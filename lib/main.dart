import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_tab.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'providers/user_provider.dart';
import 'providers/leave_provider.dart';
import 'providers/font_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'services/performance_initialization.dart';
import 'services/environment_service.dart';
import 'services/secure_storage_service.dart';
import 'services/feature_flag_service.dart';
import 'utils/asset_manager.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize date formatting for Korean locale
  await initializeDateFormatting('ko_KR', null);

  // 앱을 먼저 실행하고 초기화는 백그라운드에서 진행
  runApp(const HanslApp());

  // 초기화는 앱 실행 후 백그라운드에서 병렬 처리
  _initializeServices();
}

Future<void> _initializeServices() async {
  try {
    // 병렬로 초기화 작업 수행
    await Future.wait([
      // Firebase 초기화
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),

      // Supabase 초기화
      Supabase.initialize(
        url: 'https://qvhbigvdfyvhoegkhvef.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg',
      ),
    ]);

    if (kDebugMode) {
      debugPrint('✅ Firebase & Supabase initialized successfully');
    }

    // 나머지 초기화는 순차적으로 (빠르게 처리됨)
    try {
      await EnvironmentService.initialize();
      await SecureStorageService.migrateFromSharedPreferences();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Environment service initialization failed: $e');
      }
    }

    await NotificationService.initialize();
    await PerformanceInitialization.initialize();

    // Feature Flag 서비스 초기화
    await FeatureFlagService().initialize();
  } catch (e) {
    if (kDebugMode) {
      print('❌ Critical initialization error: $e');
    }
  }
}

class HanslApp extends StatefulWidget {
  const HanslApp({super.key});

  @override
  State<HanslApp> createState() => _HanslAppState();
}

class _HanslAppState extends State<HanslApp> with WidgetsBindingObserver {
  Widget? _initialScreen; // null로 시작하여 스플래시 화면 표시

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 네이티브 스플래시를 즉시 제거 (Flutter 화면이 준비되면 바로 보이도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // 1.5초 후에 인증 체크 시작
    _showSplashThenCheck();
  }

  Future<void> _showSplashThenCheck() async {
    debugPrint('🎬 스플래시 화면 시작 - 1.5초 대기');

    // Flutter 스플래시 화면 1.5초 표시
    await Future.delayed(const Duration(milliseconds: 1500));
    debugPrint('⏰ 1.5초 대기 완료 - 인증 체크 시작');
    await _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    // Initialize asset manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AssetManager.initialize(context);
      }

      // Enable performance monitoring in debug mode
      if (PerformanceInitialization.isInitialized) {
        PerformanceInitialization.enablePerformanceMonitoring();
      }
    });

    // Check authentication status
    try {
      debugPrint('🔍 자동 로그인 체크 시작...');
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('📱 현재 세션: ${session != null ? "존재함" : "없음"}');

      if (session != null) {
        final email = session.user.email;
        debugPrint('📧 사용자 이메일: $email');

        if (email != null) {
          final employee = await Supabase.instance.client
              .from('employees')
              .select()
              .eq('email', email)
              .maybeSingle();

          debugPrint('👤 직원 정보 조회 결과: ${employee != null ? "찾음" : "없음"}');
          if (employee != null) {
            debugPrint('👤 직원 데이터: $employee');
          }

          if (employee != null && mounted) {
            // Provider는 아직 사용할 수 없으므로, 직접 MainTab에 전달
            debugPrint('✅ 자동 로그인 성공 - 메인 화면으로 이동');
            setState(() {
              _initialScreen = MainTab(initialEmployee: employee);
            });
            return;
          }
        }
      }

      // No valid session, go to login
      debugPrint('❌ 자동 로그인 실패 - 로그인 화면으로 이동');
      if (mounted) {
        // 추가 지연 없이 바로 로그인 화면으로 이동
        setState(() {
          _initialScreen = const LoginScreen();
        });
      }
    } catch (e) {
      // Error occurred, go to login
      debugPrint('❌ 자동 로그인 에러: $e');
      if (mounted) {
        setState(() {
          _initialScreen = const LoginScreen();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose performance services when app shuts down
    PerformanceInitialization.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (PerformanceInitialization.isInitialized) {
      switch (state) {
        case AppLifecycleState.paused:
          // App goes to background - perform maintenance
          PerformanceInitialization.performMaintenance();
          break;
        case AppLifecycleState.resumed:
          // App comes to foreground - log current stats
          PerformanceInitialization.logPerformanceStats();
          break;
        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🖼️ Build 호출 - _initialScreen: ${_initialScreen != null ? "설정됨" : "null (스플래시 표시)"}',
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider<UserProvider, AttendanceProvider>(
          create: (_) => AttendanceProvider(userId: '', userName: ''),
          update: (context, userProvider, attendanceProvider) {
            if (userProvider.id != null && userProvider.name != null) {
              return AttendanceProvider(
                userId: userProvider.id!,
                userName: userProvider.name!,
              );
            }
            return attendanceProvider ??
                AttendanceProvider(userId: '', userName: '');
          },
        ),
      ],
      child: MaterialApp(
        title: 'HANSL',
        theme: AppTheme.lightTheme,
        home:
            _initialScreen ??
            const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HANSL',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1777CB),
                        letterSpacing: 4,
                        fontFamily: 'NotoSans',
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
                      '근태기록시스템',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFB0B8C1),
                        letterSpacing: 1.2,
                        fontFamily: 'NotoSans',
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
        navigatorKey: NotificationService.navigatorKey, // 알림 클릭 네비게이션을 위한 키 설정
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
