import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/main_tab.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/leave_provider.dart';
import 'theme/app_colors.dart';
import 'providers/attendance_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env 파일 로드
  await dotenv.load(fileName: ".env");
  
  // 환경변수에서 Supabase 설정 가져오기
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const HanslApp());
}

class HanslApp extends StatelessWidget {
  const HanslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
      ],
      child: Builder(
        builder: (context) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          return ChangeNotifierProvider(
            create: (_) => AttendanceProvider(
              userId: userProvider.id ?? '',
              userName: userProvider.name ?? '',
            ),
      child: MaterialApp(
        title: 'HANSL',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}
