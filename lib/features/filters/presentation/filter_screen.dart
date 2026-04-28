import 'package:flutter/material.dart';

class FilterResult {
  final String? league;
  final String? risk;
  final int minScore;

  const FilterResult({
    this.league,
    this.risk,
    required this.minScore,
  });

  bool get isActive => league != null || risk != null || minScore > 50;
}

class FilterScreen extends StatefulWidget {
  final List<String> leagues;
  final FilterResult? initialFilter;

  const FilterScreen({
    super.key,
    this.leagues = const <String>[],
    this.initialFilter,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String? selectedLeague;
  String? selectedRisk;
  late double minScore;

  @override
  void initState() {
    super.initState();
    selectedLeague = widget.initialFilter?.league;
    selectedRisk = widget.initialFilter?.risk;
    minScore = (widget.initialFilter?.minScore ?? 50).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final leagues = <String>['Alle', ...widget.leagues.where((e) => e.trim().isNotEmpty).toSet().toList()..sort()];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Spiele filtern'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedLeague = null;
                selectedRisk = null;
                minScore = 50;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionCard(
              title: 'Liga',
              child: DropdownButtonFormField<String>(
                value: selectedLeague ?? 'Alle',
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: leagues
                    .map(
                      (league) => DropdownMenuItem<String>(
                    value: league,
                    child: Text(league, overflow: TextOverflow.ellipsis),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedLeague = value == 'Alle' ? null : value);
                },
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Risiko',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChoicePill(label: 'Alle', selected: selectedRisk == null, onTap: () => setState(() => selectedRisk = null)),
                  _ChoicePill(label: 'Niedrig', selected: selectedRisk == 'Niedrig', onTap: () => setState(() => selectedRisk = 'Niedrig')),
                  _ChoicePill(label: 'Mittel', selected: selectedRisk == 'Mittel', onTap: () => setState(() => selectedRisk = 'Mittel')),
                  _ChoicePill(label: 'Hoch', selected: selectedRisk == 'Hoch', onTap: () => setState(() => selectedRisk = 'Hoch')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Mindest AI-Score: ${minScore.round()}%',
              child: Slider(
                value: minScore,
                min: 50,
                max: 95,
                divisions: 9,
                label: '${minScore.round()}%',
                onChanged: (value) => setState(() => minScore = value),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(
                  FilterResult(
                    league: selectedLeague,
                    risk: selectedRisk,
                    minScore: minScore.round(),
                  ),
                );
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Filter anwenden'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF1565C0),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF172033),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
