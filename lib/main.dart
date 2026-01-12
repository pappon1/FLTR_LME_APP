import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/admin_notification_provider.dart';
import 'services/firebase_auth_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MediaKit
  MediaKit.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E27),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Lock to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AdminNotificationProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Local Mobile Engineer Official - Admin',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show splash while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(autoNavigate: false);
        }

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<bool>(
            future: authService.isAdmin(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen(autoNavigate: false);
              }

              // Check if user is admin
              if (adminSnapshot.data == true) {
                return const HomeScreen();
              } else {
                // Not an admin, sign out and show login
                authService.signOut();
                return const LoginScreen();
              }
            },
          );
        }

        // User is not signed in
        return const LoginScreen();
      },
    );
  }
}
