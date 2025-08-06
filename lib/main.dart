import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/leave_provider.dart';
import 'providers/font_provider.dart';
import 'providers/attendance_provider.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';\nimport 'services/performance_initialization.dart';
import 'utils/asset_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // .env 파일 로드 (선택적)
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // .env 파일이 없는 경우 기본값 사용
    }
    
    // 환경변수 확인 (기본값 제공)
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://demo.supabase.co';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'demo-key';
    
    // Supabase 초기화 (실제 설정이 있는 경우만)
    if (supabaseUrl != 'https://demo.supabase.co') {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    }
    
    // Firebase 알림 서비스 초기화
    await NotificationService.initialize();
    
    // 성능 최적화 서비스 초기화 (캐시, 타이머, 비동기 작업 관리)
    await PerformanceInitialization.initialize();
    
  } catch (e) {
    // 오류가 발생해도 앱은 실행되도록 함
  }
  
  runApp(const HanslApp());
}

class HanslApp extends StatefulWidget {
  const HanslApp({super.key});

  @override
  State<HanslApp> createState() => _HanslAppState();
}

class _HanslAppState extends State<HanslApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize asset manager after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AssetManager.initialize(context);
      
      // Enable performance monitoring in debug mode
      if (PerformanceInitialization.isInitialized) {
        PerformanceInitialization.enablePerformanceMonitoring();
      }
    });
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProxyProvider<UserProvider, AttendanceProvider>(
          create: (_) => AttendanceProvider(userId: '', userName: ''),
          update: (context, userProvider, attendanceProvider) {
            if (userProvider.id != null && userProvider.name != null) {
              return AttendanceProvider(userId: userProvider.id!, userName: userProvider.name!);
            }
            return attendanceProvider ?? AttendanceProvider(userId: '', userName: '');
          },
        ),
      ],
      child: MaterialApp(
        title: 'HANSL',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        navigatorKey: NotificationService.navigatorKey, // 알림 클릭 네비게이션을 위한 키 설정
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
