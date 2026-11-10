import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/geo.dart';
import 'period.dart';
import 'social_repository.dart';

/// Classement d'un groupe sur la semaine, le mois ou l'année.
class GroupDetailScreen extends StatefulWidget {
  final RunGroup group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Period _period = Period.week;
  late Future<List<LeaderboardEntry>> _board;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() =>
      _board = context.read<SocialRepository>().leaderboard(widget.group.id, _period.start()));

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SocialRepository>();
    final isOwner = widget.group.owner == repo.userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'code', child: Text("Copier le code d'invitation")),
              PopupMenuItem(value: 'leave', child: Text(isOwner ? 'Supprimer le groupe' : 'Quitter le groupe')),
            ],
            onSelected: (v) async {
              if (v == 'code') {
                await Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Code copié')));
                }
                return;
              }
              if (isOwner) {
                await repo.deleteGroup(widget.group.id);
              } else {
                await repo.leaveGroup(widget.group.id);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
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
          const SizedBox(height: 16),
          FutureBuilder<List<LeaderboardEntry>>(
            future: _board,
            builder: (context, snap) {
              if (snap.hasError) return Text('Erreur : ${snap.error}');
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final entries = snap.data!;
              return Column(children: [
                for (final (i, e) in entries.indexed)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: switch (i) {
                        0 => Colors.amber,
                        1 => Colors.grey.shade400,
                        2 => Colors.brown.shade300,
                        _ => null,
                      },
                      child: Text('${i + 1}'),
                    ),
                    title: Text(e.label + (e.userId == repo.userId ? ' (moi)' : '')),
                    subtitle: Text('${e.runs} course${e.runs > 1 ? 's' : ''} · '
                        '${formatPace(e.avgSpeedMps)} /km · D+ ${e.elevGainM.round()} m'),
                    trailing: Text('${(e.distanceM / 1000).toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}
