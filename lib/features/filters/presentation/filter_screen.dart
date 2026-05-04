import 'package:flutter/material.dart';
import 'package:kickmind_ai/core/theme/kickmind_theme.dart';

class FilterResult {
  final String? league;
  final String? risk;
  final int minScore;

  const FilterResult({
    this.league,
    this.risk,
    required this.minScore,
  });

  bool get hasActiveFilter => league != null || risk != null || minScore > 50;
}

class FilterScreen extends StatefulWidget {
  final List<String> availableLeagues;
  final FilterResult? initialFilter;

  const FilterScreen({
    super.key,
    this.availableLeagues = const <String>[],
    this.initialFilter,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String? selectedLeague;
  String? selectedRisk;
  double minScore = 60;

  @override
  void initState() {
    super.initState();
    selectedLeague = widget.initialFilter?.league;
    selectedRisk = widget.initialFilter?.risk;
    minScore = (widget.initialFilter?.minScore ?? 60).toDouble();
  }

  List<String> get _leagues {
    final cleaned = widget.availableLeagues
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Alle', ...cleaned];
  }

  void _apply() {
    Navigator.pop(
      context,
      FilterResult(
        league: selectedLeague == null || selectedLeague == 'Alle' ? null : selectedLeague,
        risk: selectedRisk == null || selectedRisk == 'Alle' ? null : selectedRisk,
        minScore: minScore.round(),
      ),
    );
  }

  void _reset() {
    setState(() {
      selectedLeague = null;
      selectedRisk = null;
      minScore = 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Reset')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                title: 'Liga',
                icon: Icons.emoji_events_rounded,
                child: DropdownButtonFormField<String>(
                  value: selectedLeague ?? 'Alle',
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _leagues
                      .map((league) => DropdownMenuItem(value: league, child: Text(league)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedLeague = value),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Risiko',
                icon: Icons.shield_rounded,
                child: DropdownButtonFormField<String>(
                  value: selectedRisk ?? 'Alle',
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Alle', child: Text('Alle')),
                    DropdownMenuItem(value: 'Niedrig', child: Text('🟢 Niedrig')),
                    DropdownMenuItem(value: 'Mittel', child: Text('🟡 Mittel')),
                    DropdownMenuItem(value: 'Hoch', child: Text('🔴 Hoch')),
                  ],
                  onChanged: (value) => setState(() => selectedRisk = value),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Mindest AI-Score: ${minScore.round()}%',
                icon: Icons.auto_graph_rounded,
                child: Slider(
                  value: minScore,
                  min: 50,
                  max: 95,
                  divisions: 9,
                  label: '${minScore.round()}%',
                  onChanged: (value) => setState(() => minScore = value),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.filter_alt_rounded),
                label: const Text('Filter anwenden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KickMindTheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: KickMindTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
