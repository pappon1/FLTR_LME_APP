import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_kit/media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/admin_notification_provider.dart';
import 'services/firebase_auth_service.dart';
import 'utils/app_theme.dart';
import 'services/upload_service.dart';
import 'screens/uploads/upload_progress_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MediaKit
  MediaKit.ensureInitialized();
  
  // 1. Initialize Background Upload Service (Ready but silent)
  try {
     print("🛠️ Initializing Background Service...");
     await initializeUploadService();
     // Force start for debugging
     FlutterBackgroundService().startService();
     print("✅ Service Initialized & Started.");
  } catch (e) {
     print('❌ Service Init Failed: $e');
  }
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Pass all uncaught errors from the framework to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Initialize Google Sign In (Required for v7+)
  // await GoogleSignIn().signInSilently(); // Optional: Check for existing session
  
  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Force Disable Edge-to-Edge / Immersive Mode - Standard System UI
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  
  runApp(const MyApp());
}

// Global Navigation Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
          // Correctly determine if we should render dark mode
          final isSystemDark = View.of(context).platformDispatcher.platformBrightness == Brightness.dark;
          final bool isDark = themeProvider.themeMode == ThemeMode.system
              ? isSystemDark
              : themeProvider.themeMode == ThemeMode.dark;
          
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor: isDark ? AppTheme.darkBorder : null,
              systemNavigationBarContrastEnforced: true,
            ),
            child: MaterialApp(
              title: 'Local Mobile Engineer Official - Admin',
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              builder: (context, child) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: child,
                );
              },

              home: const AuthWrapper(),
            ),

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
