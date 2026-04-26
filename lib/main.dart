import 'package:flutter/material.dart';

import 'core/navigation/main_navigation_screen.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const KickMindApp());
}

class KickMindApp extends StatelessWidget {
  const KickMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KickMind AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}