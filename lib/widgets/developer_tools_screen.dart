import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import 'system_health_card.dart';
import 'tech_management_card.dart';
import 'remote_config_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DeveloperToolsScreen extends StatelessWidget {
  const DeveloperToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Developer Console", style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   Icon(Icons.terminal, color: Colors.blueAccent),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       "Advanced Tools for Admin & Developer control. Handle with care.",
                       style: GoogleFonts.inter(color: textColor.withOpacity(0.8), fontSize: 13),
                     ),
                   )
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // 1. System Health
            const SystemHealthCard(),
            const SizedBox(height: 24),

            // 2. Tech Management
            const TechManagementCard(),
            const SizedBox(height: 24),

            // 3. Remote Config / Diagnostics
            const RemoteConfigCard(),
            
            const SizedBox(height: 40),
            Center(
              child: Text("v1.0.0 (Admin Build)", style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
            ),
          ].animate(interval: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
        ),
      ),
    );
  }
}
