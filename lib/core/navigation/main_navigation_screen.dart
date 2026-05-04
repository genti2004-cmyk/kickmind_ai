import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/matches/presentation/kickmind_matches_screen.dart';
import 'package:kickmind_ai/features/top_tips/presentation/top_tips_screen.dart';
import 'package:kickmind_ai/features/analysis/presentation/analysis_screen.dart';
import 'package:kickmind_ai/features/saved_tips/presentation/saved_tips_screen.dart';
import 'package:kickmind_ai/features/odds/presentation/live_odds_screen.dart';
import 'package:kickmind_ai/features/value_bets/presentation/value_bets_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _tabIndex = 0;

  final pages = const [
    KickMindMatchesScreen(),
    TopTipsScreen(),
    AnalysisScreen(),
    SavedTipsScreen(),
    LiveOddsScreen(),      // ➕ NEU
    ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_tabIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) {
          setState(() {
            _tabIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_soccer_rounded), label: 'Heute'),
          NavigationDestination(icon: Icon(Icons.auto_graph_rounded), label: 'Top Tipps'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'Analyse'),
          NavigationDestination(icon: Icon(Icons.bookmark_rounded), label: 'Meine Tipps'),
          NavigationDestination(icon: Icon(Icons.casino_rounded), label: 'Quoten'),     // ➕
        ],
      )
    );
  }
}