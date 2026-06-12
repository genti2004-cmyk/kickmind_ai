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

  bool get _hasActiveFilter {
    return (selectedLeague != null && selectedLeague != 'Alle') ||
        (selectedRisk != null && selectedRisk != 'Alle') ||
        minScore.round() > 50;
  }

  String get _leagueLabel {
    final value = selectedLeague;
    if (value == null || value == 'Alle') return 'Alle Ligen';
    return value;
  }

  String get _riskLabel {
    final value = selectedRisk;
    if (value == null || value == 'Alle') return 'Alle Risiken';
    return value;
  }

  int get _activeFilterCount {
    var count = 0;
    if (selectedLeague != null && selectedLeague != 'Alle') count++;
    if (selectedRisk != null && selectedRisk != 'Alle') count++;
    if (minScore.round() > 50) count++;
    return count;
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
      backgroundColor: KickMindTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF061B2E),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Filter',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Zurücksetzen'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: KickMindTheme.primaryDark,
                  side: BorderSide(color: KickMindTheme.primary.withOpacity(0.22)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.filter_alt_rounded),
                label: Text(_hasActiveFilter ? 'Filter anwenden ($_activeFilterCount)' : 'Alle Spiele anzeigen'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: KickMindTheme.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterHero(
                activeFilterCount: _activeFilterCount,
                leagueLabel: _leagueLabel,
                riskLabel: _riskLabel,
                minScore: minScore.round(),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Liga',
                subtitle: '${_leagues.length - 1} Ligen verfügbar',
                icon: Icons.emoji_events_rounded,
                child: DropdownButtonFormField<String>(
                  value: selectedLeague ?? 'Alle',
                  isExpanded: true,
                  decoration: _inputDecoration('Liga auswählen'),
                  items: _leagues
                      .map(
                        (league) => DropdownMenuItem(
                      value: league,
                      child: Text(
                        league == 'Alle' ? 'Alle Ligen' : league,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (value) => setState(() => selectedLeague = value),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Risiko',
                subtitle: 'Schnell nach Risikoklasse eingrenzen',
                icon: Icons.shield_rounded,
                child: _RiskSelector(
                  selectedRisk: selectedRisk ?? 'Alle',
                  onChanged: (value) => setState(() => selectedRisk = value),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Mindest AI-Score',
                subtitle: 'Nur Spiele ab ${minScore.round()}% anzeigen',
                icon: Icons.auto_graph_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScorePreview(value: minScore.round()),
                    Slider(
                      value: minScore,
                      min: 50,
                      max: 95,
                      divisions: 9,
                      label: '${minScore.round()}%',
                      onChanged: (value) => setState(() => minScore = value),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Text(
                            'Mehr Spiele',
                            style: TextStyle(
                              color: KickMindTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Strenger',
                            style: TextStyle(
                              color: KickMindTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoBox(
                hasActiveFilter: _hasActiveFilter,
                activeFilterCount: _activeFilterCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: KickMindTheme.primary.withOpacity(0.55), width: 1.4),
      ),
    );
  }
}

class _FilterHero extends StatelessWidget {
  final int activeFilterCount;
  final String leagueLabel;
  final String riskLabel;
  final int minScore;

  const _FilterHero({
    required this.activeFilterCount,
    required this.leagueLabel,
    required this.riskLabel,
    required this.minScore,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = activeFilterCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: KickMindTheme.primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFilter ? '$activeFilterCount Filter aktiv' : 'Keine Filter aktiv',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Grenze Spiele nach Liga, Risiko und AI-Score ein.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(icon: Icons.emoji_events_rounded, text: leagueLabel),
              _HeroChip(icon: Icons.shield_rounded, text: riskLabel),
              _HeroChip(icon: Icons.auto_graph_rounded, text: 'AI ≥ $minScore%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskSelector extends StatelessWidget {
  final String selectedRisk;
  final ValueChanged<String> onChanged;

  const _RiskSelector({
    required this.selectedRisk,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _RiskOption(value: 'Alle', label: 'Alle', icon: Icons.all_inclusive_rounded, color: KickMindTheme.primary),
        _RiskOption(value: 'Niedrig', label: 'Niedrig', icon: Icons.check_circle_rounded, color: KickMindTheme.success),
        _RiskOption(value: 'Mittel', label: 'Mittel', icon: Icons.warning_amber_rounded, color: KickMindTheme.warning),
        _RiskOption(value: 'Hoch', label: 'Hoch', icon: Icons.dangerous_rounded, color: KickMindTheme.danger),
      ].map((option) {
        return _SelectableRiskOption(
          option: option,
          selected: selectedRisk == option.value,
          onTap: () => onChanged(option.value),
        );
      }).toList(),
    );
  }
}

class _RiskOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _RiskOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _SelectableRiskOption extends StatelessWidget {
  final _RiskOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableRiskOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? option.color.withOpacity(0.14) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? option.color.withOpacity(0.45) : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: 16, color: selected ? option.color : KickMindTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: TextStyle(
                color: selected ? option.color : KickMindTheme.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePreview extends StatelessWidget {
  final int value;

  const _ScorePreview({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? KickMindTheme.success
        : value >= 65
        ? KickMindTheme.primary
        : KickMindTheme.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'AI-Score mindestens $value%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            value >= 80 ? 'streng' : value >= 65 ? 'ausgewogen' : 'breit',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final bool hasActiveFilter;
  final int activeFilterCount;

  const _InfoBox({
    required this.hasActiveFilter,
    required this.activeFilterCount,
  });

  @override
  Widget build(BuildContext context) {
    final text = hasActiveFilter
        ? '$activeFilterCount Filter werden auf die aktuelle Matchliste angewendet.'
        : 'Ohne Filter werden alle aktuell geladenen Spiele angezeigt.';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF176CC7), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                height: 1.3,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KickMindTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.045)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KickMindTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: KickMindTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: KickMindTheme.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: KickMindTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
