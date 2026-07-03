import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthFlowType, FlutterAuthClientOptions, Supabase, AuthState, AuthChangeEvent;
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/main_tab.dart';
import 'screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/leave_provider.dart';
import 'providers/font_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/purchase_provider.dart';
import 'services/notification_service.dart';
import 'services/purchase_notification_listener.dart';
import 'services/performance_initialization.dart';
import 'services/secure_storage_service.dart';
import 'services/feature_flag_service.dart';
import 'services/badge_count_service.dart';
import 'screens/attendance/attendance_screen_optimized.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 화면 회전 비활성화 - 세로 모드만 허용
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // 비활성화 - Flutter SplashScreen 사용

  // Initialize date formatting for Korean locale
  await initializeDateFormatting('ko_KR', null);

  // 환경변수 먼저 로드
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Failed to load .env file, using defaults
  }

  // 필수 서비스만 빠르게 초기화 (네트워크 오류 시에도 앱 시작)
  try {
    // Firebase 초기화 (타임아웃 적용)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10));
    // Firebase initialized
  } catch (e) {
    // Firebase initialization failed, but app can still start
  }
  
  try {
    // Supabase 초기화 체크
    bool needsSupabaseInit = true;
    try {
      final _ = Supabase.instance.client;
      needsSupabaseInit = false;
      // Supabase already initialized
    } catch (e) {
      needsSupabaseInit = true;
    }
    
    // Supabase 초기화 (타임아웃 적용)
    if (needsSupabaseInit) {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? 'https://qvhbigvdfyvhoegkhvef.supabase.co',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg',
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      ).timeout(const Duration(seconds: 10));
      // Supabase initialized
    }
  } catch (e) {
    // Supabase initialization failed, but app can still start and show login screen
  }

  // 앱 실행
  runApp(const HanslApp());
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
  bool _showSplash = true; // 스플래시 화면 표시 여부
  bool _postLoginServicesInitialized = false; // 로그인 이후 서비스 초기화 여부

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auth state change listener 설정
    _setupAuthListener();

    // 스플래시 화면 제거는 _checkAuthAndRoute가 완료된 후에 처리됨
    // 여기서는 제거하지 않음

    _checkAuthAndRoute();
  }

  void _setupAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final event = data.event;
          final session = data.session;

          // 초기화가 완료된 후에만 auth 변경에 반응
          if (!_isInitialized) {
            return;
          }

          // 세션 복원 또는 로그인 시
          if ((event == AuthChangeEvent.signedIn || 
               event == AuthChangeEvent.tokenRefreshed) && 
              session != null) {
            
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
                  // 이전 화면과 다를 때만 setState 호출
                  if (_initialScreen is! MainTab) {
                    setState(() {
                      _initialScreen = MainTab(initialEmployee: employee);
                    });
                  }
                  _initializePostLoginServices();
                }
              }
            } catch (e) {
              // Employee loading failed
            }
          }
          // 로그아웃 또는 토큰 만료 시 로그인 화면으로
          else if (event == AuthChangeEvent.signedOut ||
              (event == AuthChangeEvent.tokenRefreshed && session == null)) {
            if (mounted) {
              // 이전 화면과 다를 때만 setState 호출
              if (_initialScreen is! LoginScreen) {
                setState(() {
                  _initialScreen = const LoginScreen();
                });
              }
            }
          }
        });
  }

  Future<void> _checkAuthAndRoute() async {
    
    // 최소 1.5초는 스플래시 화면 표시 (자연스러운 전환을 위해)
    final splashFuture = Future.delayed(const Duration(milliseconds: 1500));
    final authCheckFuture = _performAuthCheck();
    
    // 두 작업이 모두 완료될 때까지 대기
    final results = await Future.wait([splashFuture, authCheckFuture]);
    final authResult = results[1] as Map<String, dynamic>?;
    
    // 다음 화면 미리 준비
    if (authResult != null) {
      _initialScreen = MainTab(key: const ValueKey('main'), initialEmployee: authResult);
      _initializePostLoginServices();
    } else {
      _initialScreen = const LoginScreen(key: ValueKey('login'));
    }
    
    // 화면 준비 완료 후 부드러운 전환
    if (mounted) {
      setState(() {
        _isInitialized = true;
        // 동시에 페이드 아웃 시작
        _showSplash = false;
      });
    }
  }

  Future<void> _initializePostLoginServices() async {
    if (_postLoginServicesInitialized) return;
    _postLoginServicesInitialized = true;

    // 첫 프레임 이후 백그라운드에서 지연 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1));
      try {
        await NotificationService.initialize();
      } catch (_) {}

      try {
        await SecureStorageService.migrateFromSharedPreferences();
      } catch (_) {}

      try {
        PurchaseNotificationListener.startListening();
      } catch (_) {}

      try {
        await PerformanceInitialization.initialize();
      } catch (_) {}

      try {
        await FeatureFlagService().initialize();
      } catch (_) {}

      try {
        await BadgeCountService.updateBadgeCount();
        BadgeCountService.setupRealtimeSubscription();
      } catch (_) {}
    });
  }

  Future<Map<String, dynamic>?> _performAuthCheck() async {
    try {
      
      // Supabase 세션 체크
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        return null;
      }
      
      
      
      // 이메일 체크
      final email = session.user.email;
      if (email == null) {
        return null;
      }
      
      
      // Employee 정보 조회
      final employee = await Supabase.instance.client
          .from('employees')
          .select()
          .eq('email', email)
          .maybeSingle();
          
      if (employee == null) {
        await Supabase.instance.client.auth.signOut();
        return null;
      }
      
      return employee;
      
    } catch (e) {
      // 인증 체크 에러
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
    // 발주 알림 리스너 중지
    PurchaseNotificationListener.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (PerformanceInitialization.isInitialized) {
      switch (state) {
        case AppLifecycleState.paused:
          // App goes to background - perform maintenance
          PerformanceInitialization.performMaintenance().catchError((e) => {});
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
    
    // 디버깅 모드에서 핫리로드 시 세션 체크
    if (_isInitialized && _initialScreen is MainTab) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null && _initialScreen is! LoginScreen) {
        // build 메서드 내에서 setState 호출 방지
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _initialScreen = const LoginScreen();
            });
          }
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
            // userId가 비어있으면 기존 provider 재사용하지 않음 (새로 생성 필요)
            final currentUserId = userProvider.id ?? '';
            final currentUserName = userProvider.name ?? '';
            
            // 기존 provider가 있고, userId가 유효하고 변경되지 않았다면 그대로 사용
            if (attendanceProvider != null &&
                attendanceProvider.userId.isNotEmpty &&
                attendanceProvider.userId == currentUserId &&
                currentUserId.isNotEmpty) {
              // email만 업데이트
              if (userProvider.email != null && 
                  attendanceProvider.userEmail != userProvider.email) {
                attendanceProvider.setUserEmail(userProvider.email!);
              }
              return attendanceProvider;
            }
            
            // userId와 userName이 모두 유효한 경우에만 새로 생성
            if (currentUserId.isNotEmpty && currentUserName.isNotEmpty) {
              final provider = AttendanceProvider(
                userId: currentUserId,
                userName: currentUserName,
              );
              // email도 설정
              if (userProvider.email != null) {
                provider.setUserEmail(userProvider.email!);
              }
              return provider;
            }
            
            // userId가 비어있으면 빈 provider 반환 (하지만 canClockIn은 true로 설정됨)
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
          // 비밀번호 재설정 페이지 라우트
          // Supabase 비밀번호 재설정 콜백 처리
          if (settings.name == '/auth-callback' ||
              settings.name?.contains('#access_token') == true ||
              settings.name?.contains('type=recovery') == true) {
            // Supabase가 자동으로 토큰을 처리하므로 바로 비밀번호 재설정 화면으로
            return MaterialPageRoute(
              builder: (context) => const ResetPasswordScreen(),
            );
          }
          
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
        home: Stack(
          children: [
            // 실제 화면 (아래층) - 먼저 배치하여 준비
            if (_isInitialized && _initialScreen != null)
              AnimatedOpacity(
                opacity: _showSplash ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeIn,
                child: _initialScreen!,
              ),
            // 스플래시 화면 (위층) - 페이드 아웃
            if (_showSplash)
              AnimatedOpacity(
                opacity: _showSplash ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: const SplashScreen(),
              ),
          ],
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
