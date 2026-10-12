import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_controller.dart';
import '../../events/screens/events_screen.dart';
import '../../gallery/screens/gallery_screen.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../review/screens/review_screen.dart';
import 'more_screen.dart';

/// The bottom-nav shell. Tabs are built dynamically from the signed-in
/// member's permissions - a normal Member never even sees the icons for
/// Review or Inventory, they're not just disabled.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final s = session is SessionAuthenticated ? session.session : null;

    final tabs = <_Tab>[
      const _Tab('Home', Icons.photo_library_outlined, Icons.photo_library, GalleryScreen()),
      const _Tab('Events', Icons.event_outlined, Icons.event, EventsScreen()),
      if (s?.canApprove ?? false)
        const _Tab('Review', Icons.fact_check_outlined, Icons.fact_check, ReviewScreen()),
      if (s?.canManageInventory ?? false)
        const _Tab('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, InventoryScreen()),
      const _Tab('More', Icons.more_horiz, Icons.more_horiz, MoreScreen()),
    ];

    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (final tab in tabs) KeyedSubtree(key: ValueKey(tab.label), child: tab.screen),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.screen);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}
