import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthFlowType, FlutterAuthClientOptions, Supabase, AuthState, AuthChangeEvent;
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_tab.dart';
import 'screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'providers/user_provider.dart';
import 'providers/leave_provider.dart';
import 'providers/font_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/purchase_provider.dart';
import 'services/notification_service.dart';
import 'services/performance_initialization.dart';
import 'services/environment_service.dart';
import 'services/secure_storage_service.dart';
import 'services/feature_flag_service.dart';
import 'services/badge_count_service.dart';
// import 'services/attendance_notification_service.dart'; // 백그라운드 위치 기능 제거
import 'screens/attendance/attendance_screen_optimized.dart';

// 글로벌 네비게이터 키 (알림에서 네비게이션용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize date formatting for Korean locale
  await initializeDateFormatting('ko_KR', null);

  // 초기화를 먼저 완료한 후 앱 실행 (세션 유지를 위해)
  await _initializeServices();
  
  // 앱 실행
  runApp(const HanslApp());
}

Future<void> _initializeServices() async {
  try {
    // Supabase가 이미 초기화되었는지 확인
    bool isSupabaseInitialized = false;
    try {
      // Supabase.instance에 접근 가능하면 이미 초기화됨
      final _ = Supabase.instance.client;
      isSupabaseInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ Supabase already initialized');
        // 핫리로드 시에도 세션 체크
        final currentSession = Supabase.instance.client.auth.currentSession;
        debugPrint('🔐 Hot reload - 현재 세션: ${currentSession != null ? "유지됨" : "없음"}');
      }
    } catch (e) {
      // 초기화되지 않았으므로 초기화 필요
      isSupabaseInitialized = false;
    }

    // 병렬로 초기화 작업 수행
    final futures = <Future>[];
    
    // Firebase 초기화
    futures.add(Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform));
    
    // Supabase는 초기화되지 않았을 때만 초기화
    if (!isSupabaseInitialized) {
      futures.add(
        Supabase.initialize(
          url: 'https://qvhbigvdfyvhoegkhvef.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg',
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            autoRefreshToken: true,
          ),
        ),
      );
    }
    
    await Future.wait(futures);

    if (kDebugMode) {
      debugPrint('✅ Firebase & Supabase initialized successfully');
    }

    // 나머지 초기화는 순차적으로 (빠르게 처리됨)
    try {
      // .env 파일 직접 로드
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print('✅ .env file loaded');
      }

      // EnvironmentService는 선택적으로 초기화
      try {
        await EnvironmentService.initialize();
      } catch (e) {
        // EnvironmentService 에러는 무시하고 계속 진행
        if (kDebugMode) {
          print('⚠️ EnvironmentService init failed, but continuing: $e');
        }
      }

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

    // 출퇴근 알림 서비스 비활성화 (백그라운드 위치 기능 제거)
    // await AttendanceNotificationService.initialize();
    // await AttendanceNotificationService.startLocationBasedCheckInReminder();
    // await AttendanceNotificationService.scheduleCheckOutReminder();
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
  Widget? _initialScreen; // null로 시작 (스플래시 화면 표시)
  late final StreamSubscription<AuthState> _authStateSubscription;
  bool _isInitialized = false; // 초기화 완료 여부

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auth state change listener 설정
    _setupAuthListener();

    // 네이티브 스플래시를 즉시 제거 (Flutter 화면이 준비되면 바로 보이도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // 즉시 인증 체크 시작 (1.5초 스플래시 표시하면서)
    _checkAuthAndRoute();
  }

  void _setupAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final event = data.event;
          final session = data.session;

          if (kDebugMode) {
            print('🔐 Auth state changed: $event');
            print('🔐 Session: ${session != null ? "있음" : "없음"}');
          }

          // 초기화가 완료된 후에만 auth 변경에 반응
          if (!_isInitialized) {
            // 초기 세션 복원 이벤트 처리
            if (event == AuthChangeEvent.initialSession && session != null) {
              if (kDebugMode) {
                print('📱 초기 세션 복원됨!');
              }
            }
            return;
          }

          // 세션 복원 또는 로그인 시
          if ((event == AuthChangeEvent.signedIn || 
               event == AuthChangeEvent.tokenRefreshed) && 
              session != null) {
            if (kDebugMode) {
              print('✅ 세션 복원/로그인 감지 - 메인 화면으로');
            }
            
            // employee 정보 로드
            try {
              final email = session.user.email;
              if (email != null) {
                final employee = await Supabase.instance.client
                    .from('employees')
                    .select()
                    .eq('email', email)
                    .maybeSingle();
                    
                if (employee != null && mounted) {
                  setState(() {
                    _initialScreen = MainTab(initialEmployee: employee);
                  });
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('❌ Employee 정보 로드 실패: $e');
              }
            }
          }
          // 로그아웃 또는 토큰 만료 시 로그인 화면으로
          else if (event == AuthChangeEvent.signedOut ||
              (event == AuthChangeEvent.tokenRefreshed && session == null)) {
            if (mounted) {
              setState(() {
                _initialScreen = const LoginScreen();
              });
            }
          }
        });
  }

  Future<void> _checkAuthAndRoute() async {
    debugPrint('🎬 앱 시작 - 인증 체크 시작');
    
    // 1.5초 스플래시 표시와 동시에 인증 체크 진행
    final splashFuture = Future.delayed(const Duration(milliseconds: 1500));
    final authCheckFuture = _performAuthCheck();
    
    // 두 작업이 모두 완료될 때까지 대기
    final results = await Future.wait([splashFuture, authCheckFuture]);
    final authResult = results[1] as Map<String, dynamic>?;
    
    debugPrint('⏰ 인증 체크 완료');
    
    // 인증 결과에 따라 화면 설정
    if (mounted) {
      setState(() {
        if (authResult != null) {
          // 인증 성공 - 메인 화면으로
          debugPrint('✅ 자동 로그인 성공 - 메인 화면으로');
          _initialScreen = MainTab(initialEmployee: authResult);
        } else {
          // 인증 실패 - 로그인 화면으로
          debugPrint('❌ 자동 로그인 실패 - 로그인 화면으로');
          _initialScreen = const LoginScreen();
        }
        _isInitialized = true;
      });
    }
  }

  Future<Map<String, dynamic>?> _performAuthCheck() async {
    try {
      debugPrint('🔍 세션 체크 중...');
      
      // Supabase 세션 체크
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('❌ 세션 없음');
        return null;
      }
      
      debugPrint('📱 세션 존재');
      
      // 세션 정보 디버깅
      if (kDebugMode) {
        final expiresAt = session.expiresAt;
        if (expiresAt != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          final now = DateTime.now();
          final remaining = expiryDate.difference(now);
          debugPrint('⏰ 세션 만료 시간: $expiryDate (남은 시간: ${remaining.inMinutes}분)');
        }
      }
      
      // 이메일 체크
      final email = session.user.email;
      if (email == null) {
        debugPrint('❌ 이메일 없음');
        return null;
      }
      
      debugPrint('📧 이메일: $email');
      
      // Employee 정보 조회
      final employee = await Supabase.instance.client
          .from('employees')
          .select()
          .eq('email', email)
          .maybeSingle();
          
      if (employee == null) {
        debugPrint('❌ 직원 정보 없음');
        await Supabase.instance.client.auth.signOut();
        return null;
      }
      
      debugPrint('✅ 직원 정보 확인');
      return employee;
      
    } catch (e) {
      debugPrint('❌ 인증 체크 에러: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Dispose performance services when app shuts down
    PerformanceInitialization.dispose();
    // 배지 카운트 구독 해제
    BadgeCountService.removeSubscriptions();
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
    debugPrint('🔑 _isInitialized: $_isInitialized');
    
    // 디버깅 모드에서 핫리로드 시 세션 체크
    if (_isInitialized && _initialScreen is MainTab) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('🔴 핫리로드 감지 - 세션 없음, 로그인 화면으로 변경');
        setState(() {
          _initialScreen = const LoginScreen();
        });
      }
    }
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProxyProvider<UserProvider, AttendanceProvider>(
          create: (_) => AttendanceProvider(userId: '', userName: ''),
          update: (context, userProvider, attendanceProvider) {
            if (userProvider.id != null && userProvider.name != null) {
              final provider = AttendanceProvider(
                userId: userProvider.id!,
                userName: userProvider.name!,
              );
              // email도 설정
              if (userProvider.email != null) {
                provider.setUserEmail(userProvider.email!);
              }
              return provider;
            }
            return attendanceProvider ??
                AttendanceProvider(userId: '', userName: '');
          },
        ),
      ],
      child: MaterialApp(
        title: 'HANSL',
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey, // 글로벌 네비게이터 키 추가
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // routes 제거 - onGenerateRoute에서만 처리
        onGenerateRoute: (settings) {
          // 알림에서 전달받은 arguments 처리
          if (settings.name == '/attendance') {
            // 로그인 체크
            final session = Supabase.instance.client.auth.currentSession;
            if (session == null) {
              // 로그인이 안 되어 있으면 로그인 화면으로
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            }
            
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => AttendanceScreenOptimized(
                autoShowCheckIn: args?['autoShowCheckIn'] ?? false,
                autoShowCheckOut: args?['autoShowCheckOut'] ?? false,
              ),
            );
          }
          return null;
        },
        home: !_isInitialized 
            ? const SplashScreen()  // 초기화 전에는 스플래시
            : _initialScreen ?? const LoginScreen(), // 초기화 후: 설정된 화면 또는 로그인
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
