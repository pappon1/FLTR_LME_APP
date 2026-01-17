import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/settings/user_xray_screen.dart';
import '../screens/settings/splash_manager_screen.dart';

class RemoteConfigCard extends StatelessWidget {
  const RemoteConfigCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_remote, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Diagnostic Tools',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 1. User X-Ray Button
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: divIcon(Icons.person_search, Colors.blue),
            title: Text("User X-Ray Tool", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text("Deep scan user account issues", style: GoogleFonts.inter(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const UserXRayScreen()));
            },
          ),
          
          Divider(color: borderColor),
          
          // 2. Splash Manager Button
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: divIcon(Icons.wallpaper, Colors.pinkAccent),
            title: Text("Splash Screen Manager", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text("Change app startup image", style: GoogleFonts.inter(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SplashManagerScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget divIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
