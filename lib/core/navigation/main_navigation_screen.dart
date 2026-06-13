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
  int _analysisRefreshKey = 0;
  int _liveOddsRefreshKey = 0;

  Widget _buildCurrentPage() {
    // Wichtig: keine IndexedStack-Pages vorab bauen.
    // Sonst starten Top Tipps, Analyse und Quoten sofort beim App-Start
    // und lösen parallel API-/ESPN-/SportsDB-Abfragen aus.
    switch (_tabIndex) {
      case 0:
        return HomeScreen(key: ValueKey<String>('home_$_homeRefreshKey'));
      case 1:
        return TopTipsScreen(key: ValueKey<String>('top_tips_$_topTipsRefreshKey'));
      case 2:
        return AnalysisScreen(key: ValueKey<String>('analysis_$_analysisRefreshKey'));
      case 3:
        return SavedTipsScreen(key: ValueKey<String>('saved_tips_$_savedTipsRefreshKey'));
      case 4:
        return LiveOddsScreen(key: ValueKey<String>('live_odds_$_liveOddsRefreshKey'));
      default:
        return HomeScreen(key: ValueKey<String>('home_$_homeRefreshKey'));
    }
  }

  static const List<NavigationDestination> _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Start',
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

      // Nur der geöffnete Tab wird gebaut. Beim erneuten Öffnen laden
      // dynamische Screens frisch, aber nicht schon beim App-Start.
      if (value == 0) {
        _homeRefreshKey++;
      } else if (value == 1) {
        _topTipsRefreshKey++;
      } else if (value == 2) {
        _analysisRefreshKey++;
      } else if (value == 3) {
        _savedTipsRefreshKey++;
      } else if (value == 4) {
        _liveOddsRefreshKey++;
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
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 88,
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primary.withOpacity(0.14),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
              final selected = states.contains(WidgetState.selected);
              return theme.textTheme.labelSmall!.copyWith(
                fontSize: 10.5,
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
