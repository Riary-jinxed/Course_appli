import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/run.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
import '../share/run_share_card.dart';
import '../theme/app_theme.dart';
import '../coach/coach_screen.dart';
import '../notifications/reminders_screen.dart';
import '../records/records_screen.dart';
import '../safety/safety_screen.dart';
import '../shoes/shoes_screen.dart';
import '../weather/weather_card.dart';
import '../social/backup_service.dart';
import 'live_run_screen.dart';
import 'profile_screen.dart';
import 'run_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Run>> _runs;

  late final BackupService _backup;
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _backup = context.read<BackupService>()..addListener(_onBackup);
  }

  /// Recharge la liste quand une synchro vient de restaurer des courses.
  void _onBackup() {
    if (_wasSyncing && !_backup.syncing && mounted) _reload();
    _wasSyncing = _backup.syncing;
  }

  @override
  void dispose() {
    _backup.removeListener(_onBackup);
    super.dispose();
  }

  void _reload() => setState(() => _runs = context.read<RunRepository>().list());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<ProfileState>().profile?.name ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Mes courses' : 'Salut $name 👋'),
        actions: [
          if (context.watch<BackupService>().available) const _SyncButton(),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Assistante',
            onPressed: () => _open(const CoachScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Mes records',
            onPressed: () => _open(const RecordsScreen()),
          ),
          PopupMenuButton<Widget>(
            tooltip: 'Plus',
            onSelected: _open,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ProfileScreen(), child: ListTile(leading: Icon(Icons.person), title: Text('Profil'))),
              PopupMenuItem(value: ShoesScreen(), child: ListTile(leading: Icon(Icons.hiking), title: Text('Chaussures'))),
              PopupMenuItem(value: SafetyScreen(), child: ListTile(leading: Icon(Icons.shield), title: Text('Sécurité'))),
              PopupMenuItem(value: RemindersScreen(), child: ListTile(leading: Icon(Icons.notifications), title: Text('Rappels'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'start_run',
        icon: const Icon(Icons.directions_run),
        label: const Text('Démarrer'),
        onPressed: () => _open(const LiveRunScreen()),
      ),
      body: FutureBuilder<List<Run>>(
        future: _runs,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final runs = snap.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 104),
            children: [
              _SummaryHero(runs: runs),
              const WeatherCard(),
              if (runs.isEmpty)
                const _EmptyState()
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Dernières courses', style: Theme.of(context).textTheme.titleLarge),
                ),
                for (final r in runs) _RunCard(run: r, onTap: () => _open(RunDetailScreen(runId: r.id!))),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Carte d'en-tête : kilomètres de la semaine et cumul.
class _SummaryHero extends StatelessWidget {
  final List<Run> runs;
  const _SummaryHero({required this.runs});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final week = runs.where((r) => !r.startedAt.isBefore(monday)).toList();
    final weekKm = week.fold<double>(0, (s, r) => s + r.distanceM) / 1000;
    final weekTime = week.fold<Duration>(Duration.zero, (s, r) => s + r.movingTime);
    final totalKm = runs.fold<double>(0, (s, r) => s + r.distanceM) / 1000;
    // Jours de la semaine où l'on a couru (lundi = 0).
    final days = {for (final r in week) r.startedAt.weekday - 1};
    const white70 = Color(0xB3FFFFFF);
    Widget mini(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: white70)),
          Text(value, style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontFeatures: tabular)),
        ]);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.ember.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CETTE SEMAINE', style: t.labelSmall?.copyWith(color: white70, letterSpacing: 1.6)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(weekKm.toStringAsFixed(1),
              style: t.displayMedium?.copyWith(color: Colors.white, height: 1, fontFeatures: tabular)),
          const SizedBox(width: 6),
          Text('km', style: t.titleLarge?.copyWith(color: white70)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (i, d) in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'].indexed)
            Column(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: days.contains(i) ? Colors.white : Colors.white.withValues(alpha: 0.18),
                ),
                child: days.contains(i) ? const Icon(Icons.directions_run, size: 18, color: AppColors.ember) : null,
              ),
              const SizedBox(height: 4),
              Text(d, style: t.labelSmall?.copyWith(color: i == now.weekday - 1 ? Colors.white : white70)),
            ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: mini('Sorties', '${week.length}')),
          Expanded(child: mini('Temps', formatDuration(weekTime))),
          Expanded(child: mini('Au total', '${totalKm.toStringAsFixed(0)} km')),
        ]),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(Icons.directions_run, size: 44, color: scheme.primary),
        ),
        const SizedBox(height: 16),
        Text('Aucune course pour le moment', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Touche « Démarrer » et lance-toi !',
            style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Une course de la liste : aperçu du tracé et chiffres clés.
class _RunCard extends StatelessWidget {
  final Run run;
  final VoidCallback onTap;
  const _RunCard({required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    Widget metric(String value, String unit) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
            const SizedBox(width: 2),
            Text(unit, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        );
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(8),
              child: _RouteThumb(runId: run.id!),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(toBeginningOfSentenceCase(DateFormat('EEEE d MMM · HH:mm', 'fr_FR').format(run.startedAt)),
                    style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text((run.distanceM / 1000).toStringAsFixed(2),
                      style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
                  const SizedBox(width: 3),
                  Text('km', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 2),
                Wrap(spacing: 14, children: [
                  metric(formatDuration(run.movingTime), ''),
                  metric(formatPace(run.avgSpeedMps), '/km'),
                  if (run.elevationGainM >= 5) metric('${run.elevationGainM.round()}', 'm D+'),
                ]),
              ]),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

/// Miniature du tracé, chargée à la demande (la liste ne contient pas les points).
class _RouteThumb extends StatefulWidget {
  final int runId;
  const _RouteThumb({required this.runId});

  @override
  State<_RouteThumb> createState() => _RouteThumbState();
}

class _RouteThumbState extends State<_RouteThumb> {
  static final _cache = <int, List<TrackPoint>>{};
  List<TrackPoint>? _points;

  @override
  void initState() {
    super.initState();
    _points = _cache[widget.runId];
    if (_points == null) {
      context.read<RunRepository>().get(widget.runId).then((r) {
        final pts = r?.points ?? const <TrackPoint>[];
        _cache[widget.runId] = pts;
        if (mounted) setState(() => _points = pts);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = _points;
    final color = Theme.of(context).colorScheme.primary;
    if (pts == null || pts.length < 2) {
      return Icon(Icons.directions_run, color: color.withValues(alpha: 0.6), size: 30);
    }
    return CustomPaint(
      painter: RoutePainter(pts, const [], color, paceColors: true, strokeWidth: 2.5, glow: false),
      size: Size.infinite,
    );
  }
}

/// État de la sauvegarde en ligne ; un appui relance la synchro.
class _SyncButton extends StatelessWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BackupService>();
    if (b.syncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      icon: Icon(b.lastError != null ? Icons.cloud_off : Icons.cloud_done),
      tooltip: b.lastError != null ? 'Sauvegarde en échec, toucher pour réessayer' : 'Courses sauvegardées en ligne',
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final n = await b.sync();
        messenger.showSnackBar(SnackBar(
          content: Text(b.lastError != null
              ? 'Sauvegarde impossible : vérifie ta connexion'
              : n > 0
                  ? '$n course${n > 1 ? 's' : ''} restaurée${n > 1 ? 's' : ''}'
                  : 'Toutes tes courses sont sauvegardées'),
        ));
      },
    );
  }
}
