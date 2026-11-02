import 'package:flutter/material.dart';

/// タブアイテムの定義
class TabItem {
  const TabItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.page,
    this.navigatorKey,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget page;

  /// タブ内ナビゲーション用のキー
  final GlobalKey<NavigatorState>? navigatorKey;
}

/// ボトムナビゲーションバー
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<TabItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        for (final (index, item) in items.indexed)
          NavigationDestination(
            key: ValueKey('bottom-navigation-tab-$index'),
            icon: Icon(item.icon),
            selectedIcon: item.selectedIcon != null
                ? Icon(item.selectedIcon!)
                : null,
            label: item.label,
          ),
      ],
    );
  }
}
