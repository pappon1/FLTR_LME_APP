import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/firebase_auth_service.dart';
import '../../utils/quick_cleanup.dart';
import '../login_screen.dart';
import '../admin/course_migration_screen.dart';
import 'dart:async';
import 'admin_profile_screen.dart';
import 'app_control_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTheme.heading2(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Section
          Text(
            'GENERAL',
            style: AppTheme.bodySmall(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.user,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Profile', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Edit your profile information', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.infoGradient,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.sliders,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('App Control Center', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Version, Maintenance & Global Config', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AppControlScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Appearance Section
          Text(
            'APPEARANCE',
            style: AppTheme.bodySmall(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.warningGradient,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: FaIcon(
                      themeProvider.isDarkMode
                          ? FontAwesomeIcons.moon
                          : FontAwesomeIcons.sun,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Dark Mode', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Switch between light and dark theme', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                  activeThumbColor: AppTheme.primaryColor,
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // About Section
          Text(
            'ABOUT',
            style: AppTheme.bodySmall(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.circleInfo,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('App Version', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('1.0.0', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  trailing: null,
                  onTap: null,
                ),
              ],
            ),
          ),
          
          
          const SizedBox(height: 24),
          
          // 🔥 DEVELOPER ZONE Section
          Text(
            '🔥 DEVELOPER ZONE',
            style: AppTheme.bodySmall(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.red.shade50,
            elevation: 4,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '⚠️ DANGER: These options are irreversible!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.database,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Course Migration Tool',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  subtitle: const Text(
                    'Fix duration format in old courses',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                    color: Colors.blue,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CourseMigrationScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                      ),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.trash,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Database Cleanup',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  subtitle: const Text(
                    'Delete all courses & files from server',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                    color: Colors.red,
                  ),
                  onTap: () {
                    QuickCleanup.showQuickDeleteButton(context);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Button
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                         Navigator.pop(context);
                         unawaited(FirebaseAuthService().signOut());
                         Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                         );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

