import 'package:flutter/material.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info & Rechtliches'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'KickMind AI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),

            SizedBox(height: 24),

            Text(
              '⚠️ Hinweis',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Diese App dient ausschließlich der Analyse und Unterhaltung. '
                  'Es werden keine garantierten Vorhersagen oder Gewinne versprochen.',
            ),

            SizedBox(height: 16),

            Text(
              '📊 Nutzung',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Alle Tipps basieren auf statistischen Modellen und automatisierten Berechnungen.',
            ),

            SizedBox(height: 16),

            Text(
              '⚖️ Haftungsausschluss',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Die Nutzung erfolgt auf eigene Verantwortung. '
                  'Der Entwickler übernimmt keine Haftung für Verluste oder Entscheidungen.',
            ),

            SizedBox(height: 16),

            Text(
              '🔒 Datenschutz',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Es werden keine personenbezogenen Daten gespeichert oder weitergegeben.',
            ),
          ],
        ),
      ),
    );
  }
}