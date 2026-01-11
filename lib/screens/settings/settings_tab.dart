import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';

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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.user,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Profile'),
                  subtitle: const Text('Edit your profile information'),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.infoGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.building,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('App Settings'),
                  subtitle: const Text('Configure app preferences'),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () {},
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FaIcon(
                      themeProvider.isDarkMode
                          ? FontAwesomeIcons.moon
                          : FontAwesomeIcons.sun,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Switch between light and dark theme'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                  activeColor: AppTheme.primaryColor,
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Notifications Section
          Text(
            'NOTIFICATIONS',
            style: AppTheme.bodySmall(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.successGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.bell,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive notifications on your device'),
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppTheme.primaryColor,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.infoGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.envelope,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive updates via email'),
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppTheme.primaryColor,
                ),
              ],
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.circleInfo,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.warningGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.fileLines,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Terms & Privacy'),
                  subtitle: const Text('Read our policies'),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () {},
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
                      onPressed: () {},
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
