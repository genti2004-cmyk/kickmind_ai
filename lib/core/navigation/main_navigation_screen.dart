import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/analysis/presentation/analysis_screen.dart';
import 'package:kickmind_ai/features/matches/presentation/kickmind_matches_screen.dart';
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
  int _topTipsRefreshKey = 0;
  int _savedTipsRefreshKey = 0;

  List<Widget> get _pages => <Widget>[
    const KickMindMatchesScreen(),
    TopTipsScreen(key: ValueKey<String>('top_tips_$_topTipsRefreshKey')),
    const AnalysisScreen(),
    SavedTipsScreen(key: ValueKey<String>('saved_tips_$_savedTipsRefreshKey')),
    const LiveOddsScreen(),
  ];

  static const List<NavigationDestination> _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.sports_soccer_outlined),
      selectedIcon: Icon(Icons.sports_soccer_rounded),
      label: 'Heute',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_graph_outlined),
      selectedIcon: Icon(Icons.auto_graph_rounded),
      label: 'Top Tipps',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics_rounded),
      label: 'Analyse',
    ),
    NavigationDestination(
      icon: Icon(Icons.bookmark_border_rounded),
      selectedIcon: Icon(Icons.bookmark_rounded),
      label: 'Meine Tipps',
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

      // These tabs load async data and are kept alive by IndexedStack.
      // Re-key them when opened so newly saved tips and late API results
      // are visible immediately without restarting the app.
      if (value == 1) {
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
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 72,
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
              final selected = states.contains(WidgetState.selected);
              return theme.textTheme.labelSmall!.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: selected ? 25 : 23,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: _selectTab,
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}
