import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/dashboard_provider.dart';
import '../utils/app_theme.dart';
import 'dashboard/dashboard_tab.dart';
import 'courses/courses_tab.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'settings/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = const [
    DashboardTab(),
    CoursesTab(),
    SettingsTab(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: FaIcon(FontAwesomeIcons.chartPie, size: 20),
      selectedIcon: FaIcon(FontAwesomeIcons.chartPie, size: 20, color: Colors.white),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: FaIcon(FontAwesomeIcons.graduationCap, size: 20),
      selectedIcon: FaIcon(FontAwesomeIcons.graduationCap, size: 20, color: Colors.white),
      label: 'Courses',
    ),
    NavigationDestination(
      icon: FaIcon(FontAwesomeIcons.gear, size: 20),
      selectedIcon: FaIcon(FontAwesomeIcons.gear, size: 20, color: Colors.white),
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Check Notification Permission on First Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _checkNotificationPermission();
       _checkPendingUploads(); // Auto-navigate if upload is in progress
    });
  }

  Future<void> _checkPendingUploads() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      // Don't auto-navigate! User should manually open upload screen if they want.
      // Background service runs always, but uploads might be idle.
      // We'll just let the badge in CoursesTab handle notification.
      
      // Optional: You can add a one-time check here to show a toast/snackbar
      // if there are active uploads, but DON'T force navigation.
    }
  }

  Future<void> _checkNotificationPermission() async {
    // We import permission_handler at the top
    // but using fully qualified name to avoid conflict with file pickers if any
    if (await Permission.notification.isDenied) {
        _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 10),
            Text('Notifications Required'),
          ],
        ),
        content: const Text(
          'To monitor background course uploads, this app needs notification permission. Without this, uploads might stop or fail silently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip (Risk)', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton.icon(
            onPressed: () async {
               await Permission.notification.request();
               // Open Settings if permanently denied
               if (await Permission.notification.isPermanentlyDenied) {
                 openAppSettings();
               }
               if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('Allow Access'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: IndexedStack(
            index: provider.selectedIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: AppTheme.primaryColor,
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Colors.white);
                  }
                  return IconThemeData(color: Theme.of(context).textTheme.bodyMedium?.color);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    );
                  }
                  return GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: provider.selectedIndex,
                onDestinationSelected: provider.setSelectedIndex,
                destinations: _destinations,
                backgroundColor: Theme.of(context).cardColor,
                elevation: 0,
                height: 65,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              ),
            ),
          ),
        );
      },
    );
  }
}
