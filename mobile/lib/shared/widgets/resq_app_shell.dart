import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/features/alerts/presentation/pages/alerts_page.dart';
import 'package:resqconnect/features/feed/presentation/pages/create_incident_page.dart';
import 'package:resqconnect/features/feed/presentation/pages/home_dashboard_page.dart';
import 'package:resqconnect/features/map/presentation/pages/explore_map_page.dart';
import 'package:resqconnect/features/profile/presentation/pages/profile_page.dart';

class ResQAppShell extends StatefulWidget {
  final int initialIndex;

  const ResQAppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<ResQAppShell> createState() => _ResQAppShellState();
}

class _ResQAppShellState extends State<ResQAppShell> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomeDashboardPage(),
    ExploreMapPage(),
    CreateIncidentPage(),
    AlertsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primaryEmergencyRed,
          unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, color: AppColors.primaryEmergencyRed),
              label: 'HOME',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded, color: AppColors.primaryEmergencyRed),
              label: 'EXPLORE',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryEmergencyRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
              label: 'CREATE',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications_rounded, color: AppColors.primaryEmergencyRed),
              label: 'ALERTS',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded, color: AppColors.primaryEmergencyRed),
              label: 'PROFILE',
            ),
          ],
        ),
      ),
    );
  }
}
