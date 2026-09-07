import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../l10n/language_controller.dart';
import 'ai_screen.dart';
import 'analytics_screen.dart';
import 'overview_screen.dart';
import 'provision_device_screen.dart';
import 'settings_screen.dart';
import 'spaces_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int index = widget.initialIndex;

  final pages = const [
    OverviewScreen(),
    SpacesScreen(),
    AnalyticsScreen(),
    AiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: context.tr('Home', 'Αρχική'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.apartment_outlined),
            selectedIcon: const Icon(Icons.apartment_rounded),
            label: context.tr('Spaces', 'Χώροι'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: context.tr('Analytics', 'Αναλύσεις'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'AI',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('Settings', 'Ρυθμίσεις'),
          ),
        ],
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton(
              backgroundColor: EdgeColors.blueStrong,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProvisionDeviceScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
