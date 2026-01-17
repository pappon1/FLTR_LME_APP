import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/dashboard_provider.dart';
import '../utils/app_theme.dart';
import 'dashboard/dashboard_tab.dart';
import 'courses/courses_tab.dart';
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
                  return IconThemeData(color: Colors.grey[600]);
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
                    color: Colors.grey[600],
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
