import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/analysis/presentation/analysis_screen.dart';
import 'package:kickmind_ai/features/home/presentation/home_screen.dart';
import 'package:kickmind_ai/features/odds/presentation/live_odds_screen.dart';
import 'package:kickmind_ai/features/saved_tips/presentation/saved_tips_screen.dart';
import 'package:kickmind_ai/features/top_tips/presentation/top_tips_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _tabIndex = 0;
  int _homeRefreshKey = 0;
  int _topTipsRefreshKey = 0;
  int _savedTipsRefreshKey = 0;

  List<Widget> get _pages => <Widget>[
    HomeScreen(key: ValueKey<String>('home_$_homeRefreshKey')),
    TopTipsScreen(key: ValueKey<String>('top_tips_$_topTipsRefreshKey')),
    const AnalysisScreen(),
    SavedTipsScreen(key: ValueKey<String>('saved_tips_$_savedTipsRefreshKey')),
    const LiveOddsScreen(),
  ];

  static const List<NavigationDestination> _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Start',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_graph_outlined),
      selectedIcon: Icon(Icons.auto_graph_rounded),
      label: 'Tipps',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics_rounded),
      label: 'Analyse',
    ),
    NavigationDestination(
      icon: Icon(Icons.bookmark_border_rounded),
      selectedIcon: Icon(Icons.bookmark_rounded),
      label: 'Merkliste',
    ),
    NavigationDestination(
      icon: Icon(Icons.casino_outlined),
      selectedIcon: Icon(Icons.casino_rounded),
      label: 'Quoten',
    ),
  ];

  void _selectTab(int value) {
    setState(() {
      _tabIndex = value;

      // Async tabs stay alive inside IndexedStack. Re-key the dynamic tabs
      // when opened so newly loaded odds and saved tips are visible without
      // restarting the app.
      if (value == 0) {
        _homeRefreshKey++;
      } else if (value == 1) {
        _topTipsRefreshKey++;
      } else if (value == 3) {
        _savedTipsRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 76,
                  backgroundColor: colorScheme.surface,
                  indicatorColor: colorScheme.primary.withOpacity(0.13),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
                    final selected = states.contains(WidgetState.selected);
                    return theme.textTheme.labelSmall!.copyWith(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      letterSpacing: -0.1,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: selected ? 24 : 22,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: _selectTab,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: _destinations,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
