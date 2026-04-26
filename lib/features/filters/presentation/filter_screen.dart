import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../matches/data/mock_matches_repository.dart';
import '../../matches/domain/football_match.dart';
import '../../matches/presentation/match_card.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  int minScore = 75;
  RiskLevel? selectedRisk;
  TipType? selectedTipType;

  @override
  Widget build(BuildContext context) {
    final allMatches = const MockMatchesRepository().getTodayMatches();

    final filteredMatches = allMatches.where((match) {
      final scoreOk = match.aiScore >= minScore;
      final riskOk = selectedRisk == null || match.riskLevel == selectedRisk;
      final typeOk = selectedTipType == null || match.tipType == selectedTipType;

      return scoreOk && riskOk && typeOk;
    }).toList()
      ..sort((a, b) => b.aiScore.compareTo(a.aiScore));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Filter'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _FilterHeader(count: filteredMatches.length),
          const SizedBox(height: 16),

          _SectionTitle(title: 'KI-Score ab $minScore%'),
          Slider(
            value: minScore.toDouble(),
            min: 50,
            max: 95,
            divisions: 9,
            label: '$minScore%',
            activeColor: AppTheme.blue,
            inactiveColor: AppTheme.card,
            onChanged: (value) {
              setState(() => minScore = value.round());
            },
          ),

          const SizedBox(height: 10),
          const _SectionTitle(title: 'Risiko'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChoicePill(
                label: 'Alle',
                selected: selectedRisk == null,
                onTap: () => setState(() => selectedRisk = null),
              ),
              _ChoicePill(
                label: 'Niedrig',
                selected: selectedRisk == RiskLevel.low,
                onTap: () => setState(() => selectedRisk = RiskLevel.low),
              ),
              _ChoicePill(
                label: 'Mittel',
                selected: selectedRisk == RiskLevel.medium,
                onTap: () => setState(() => selectedRisk = RiskLevel.medium),
              ),
              _ChoicePill(
                label: 'Hoch',
                selected: selectedRisk == RiskLevel.high,
                onTap: () => setState(() => selectedRisk = RiskLevel.high),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const _SectionTitle(title: 'Tipp-Art'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChoicePill(
                label: 'Alle',
                selected: selectedTipType == null,
                onTap: () => setState(() => selectedTipType = null),
              ),
              _ChoicePill(
                label: 'Heimsieg',
                selected: selectedTipType == TipType.homeWin,
                onTap: () => setState(() => selectedTipType = TipType.homeWin),
              ),
              _ChoicePill(
                label: 'Doppelchance',
                selected: selectedTipType == TipType.doubleChance,
                onTap: () => setState(() => selectedTipType = TipType.doubleChance),
              ),
              _ChoicePill(
                label: 'Über 2.5',
                selected: selectedTipType == TipType.over25,
                onTap: () => setState(() => selectedTipType = TipType.over25),
              ),
              _ChoicePill(
                label: 'Beide treffen',
                selected: selectedTipType == TipType.bothTeamsScore,
                onTap: () => setState(() => selectedTipType = TipType.bothTeamsScore),
              ),
            ],
          ),

          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(title: 'Gefilterte Tipps'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    minScore = 75;
                    selectedRisk = null;
                    selectedTipType = null;
                  });
                },
                child: const Text('Zurücksetzen'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredMatches.isEmpty)
            const _EmptyResultCard()
          else
            ...filteredMatches.map(
                  (match) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MatchCard(match: match),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterHeader extends StatelessWidget {
  final int count;

  const _FilterHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: AppTheme.blue, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '$count passende Tipps gefunden.\nPasse Score, Risiko und Tipp-Art an.',
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
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
      selectedColor: AppTheme.blue,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.text,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected ? AppTheme.blue : AppTheme.blue.withOpacity(0.16),
      ),
    );
  }
}

class _EmptyResultCard extends StatelessWidget {
  const _EmptyResultCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.blue.withOpacity(0.12)),
      ),
      child: const Text(
        'Keine Spiele gefunden. Senke den KI-Score oder ändere die Filter.',
        style: TextStyle(
          color: AppTheme.mutedText,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.text,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}