import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayoutScreen extends StatelessWidget {
  final Widget child;

  const MainLayoutScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop / Tablet layout: Wide aspect ratio screens
        if (constraints.maxWidth > 768) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth > 1024,
                  backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
                  unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.5)),
                  selectedIconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
                  selectedLabelTextStyle: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w900,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                  ),
                  onDestinationSelected: (int index) => _navigateTo(context, index),
                  selectedIndex: _calculateSelectedIndex(context),
                  labelType: constraints.maxWidth > 1024
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_today),
                      label: Text('Schedule'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.timeline_outlined),
                      selectedIcon: Icon(Icons.timeline),
                      label: Text('Progress'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: Text('Tasks'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.apps_outlined),
                      selectedIcon: Icon(Icons.apps),
                      label: Text('Services'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF1E293B)),
                Expanded(child: child),
              ],
            ),
          );
        }

        // Mobile layout: Narrow viewport
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            onDestinationSelected: (int index) => _navigateTo(context, index),
            selectedIndex: _calculateSelectedIndex(context),
            backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
            indicatorColor: const Color(0xFFD4AF37).withOpacity(0.2),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.timeline_outlined),
                selectedIcon: Icon(Icons.timeline),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.apps_outlined),
                selectedIcon: Icon(Icons.apps),
                label: 'Services',
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/schedule-manager');
        break;
      case 2:
        context.go('/semester-progress');
        break;
      case 3:
        context.go('/tasks');
        break;
      case 4:
        context.go('/services');
        break;
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/schedule-manager')) return 1;
    if (location.startsWith('/semester-progress')) return 2;
    if (location.startsWith('/tasks')) return 3;
    if (location.startsWith('/services')) return 4;
    return 0;
  }
}
