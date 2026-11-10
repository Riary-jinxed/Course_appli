import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/geo.dart';
import 'period.dart';
import 'social_repository.dart';

/// Compare mes stats partagées avec celles d'un ami sur une période.
class CompareScreen extends StatefulWidget {
  final PublicProfile me;
  final PublicProfile other;
  const CompareScreen({super.key, required this.me, required this.other});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  Period _period = Period.month;
  late Future<(StatsSummary, StatsSummary)> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<SocialRepository>();
    final since = _period.start();
    setState(() {
      _data = () async {
        final mine = await repo.runsOf(widget.me.id, since);
        final theirs = await repo.runsOf(widget.other.id, since);
        return (StatsSummary.of(mine), StatsSummary.of(theirs));
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Moi vs ${widget.other.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<Period>(
            segments: [for (final p in Period.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {_period},
            onSelectionChanged: (s) {
              _period = s.first;
              _reload();
            },
          ),
          const SizedBox(height: 24),
          FutureBuilder<(StatsSummary, StatsSummary)>(
            future: _data,
            builder: (context, snap) {
              if (snap.hasError) return Text('Erreur : ${snap.error}');
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final (a, b) = snap.data!;
              String km(double m) => '${(m / 1000).toStringAsFixed(1)} km';
              return Column(children: [
                _Row('', 'Moi', widget.other.label, header: true),
                _Row('Courses', '${a.runs}', '${b.runs}', aWins: a.runs > b.runs, bWins: b.runs > a.runs),
                _Row('Distance', km(a.distanceM), km(b.distanceM),
                    aWins: a.distanceM > b.distanceM, bWins: b.distanceM > a.distanceM),
                _Row('Temps', formatDuration(Duration(seconds: a.movingS)),
                    formatDuration(Duration(seconds: b.movingS)),
                    aWins: a.movingS > b.movingS, bWins: b.movingS > a.movingS),
                _Row('Allure moy.', formatPace(a.avgSpeedMps), formatPace(b.avgSpeedMps),
                    aWins: a.avgSpeedMps > b.avgSpeedMps && b.runs > 0,
                    bWins: b.avgSpeedMps > a.avgSpeedMps && a.runs > 0),
                _Row('Plus longue', km(a.longestM), km(b.longestM),
                    aWins: a.longestM > b.longestM, bWins: b.longestM > a.longestM),
                _Row('D+', '${a.elevGainM.round()} m', '${b.elevGainM.round()} m',
                    aWins: a.elevGainM > b.elevGainM, bWins: b.elevGainM > a.elevGainM),
                const SizedBox(height: 16),
                const Text('Seules les courses partagées sont comptées.', style: TextStyle(fontSize: 12)),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, a, b;
  final bool aWins, bWins, header;
  const _Row(this.label, this.a, this.b, {this.aWins = false, this.bWins = false, this.header = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final win = TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold);
    final base = header ? t.titleMedium : t.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: t.labelLarge)),
        Expanded(flex: 3, child: Text(a, textAlign: TextAlign.center, style: aWins ? base?.merge(win) : base)),
        Expanded(flex: 3, child: Text(b, textAlign: TextAlign.center, style: bWins ? base?.merge(win) : base)),
      ]),
    );
  }
}
