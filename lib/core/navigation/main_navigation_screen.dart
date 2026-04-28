import 'package:flutter/material.dart';
import 'package:kickmind_ai/features/home/presentation/home_screen.dart';
import 'package:kickmind_ai/features/saved_tips/presentation/saved_tips_screen.dart';
import 'package:kickmind_ai/features/settings/presentation/app_info_screen.dart';

import 'package:kickmind_ai/features/top_tips/presentation/top_tips_screen.dart';
// Falls du einen TopTipsScreen hast, import aktivieren:
// import 'package:kickmind_ai/features/tips/presentation/top_tips_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const HomeScreen(),
    const TopTipsScreen(),
    const SavedTipsScreen(),
    const AppInfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department),
            label: 'Top Tipps',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark),
            label: 'Meine Tipps',
          ),
          NavigationDestination(
            icon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}