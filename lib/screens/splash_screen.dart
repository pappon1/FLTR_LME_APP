import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool autoNavigate;
  const SplashScreen({super.key, this.autoNavigate = true});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoNavigate) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 3));

    if (mounted && widget.autoNavigate) {
      unawaited(Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E27), Color(0xFF151935), Color(0xFF1E2442)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with pulse animation
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(3.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  FontAwesomeIcons.mobileScreenButton,
                  size: 60,
                  color: Colors.white,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2000.ms, color: Colors.white24)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 30),

              // App Name
              Text(
                'Mobile Repair Pro',
                style: AppTheme.heading1(context).copyWith(
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms, delay: 300.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Admin Dashboard',
                style: AppTheme.bodyLarge(context).copyWith(
                  color: Colors.white60,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms, delay: 500.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms),

              const SizedBox(height: 50),

              // Loading indicator
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3.0),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 1500.ms)
                  .animate()
                  .fadeIn(delay: 700.ms),

              const SizedBox(height: 20),

              Text(
                'Loading...',
                style: AppTheme.bodySmall(context).copyWith(
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 800.ms)
                  .then()
                  .fadeOut(duration: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}

