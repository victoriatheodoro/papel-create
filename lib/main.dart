import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'models/activity_group.dart';
import 'models/scan_result.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/review_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('=== FLUTTER ERROR: ${details.exceptionAsString()} ===');
  };
  runZonedGuarded(
    () => runApp(const AnalogSyncApp()),
    (error, stack) {
      // ignore: avoid_print
      print('=== ZONE ERROR: $error ===');
      // ignore: avoid_print
      print(stack);
    },
  );
}

class AnalogSyncApp extends StatelessWidget {
  const AnalogSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papel & Create',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC17FD4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F7F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9F7F0),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF2D2D2D),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2D2D2D)),
        ),
      ),
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/review':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ReviewScreen(
                scanResult: args['result'] as ScanResult,
                groups: List<ActivityGroup>.from(
                    args['groups'] as List? ?? []),
              ),
            );
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
