import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/run.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
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
        title: Text(name.isEmpty ? 'Mes courses' : 'Salut $name'),
        actions: [
          if (context.watch<BackupService>().available) const _SyncButton(),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profil',
            onPressed: () => _open(const ProfileScreen()),
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
          if (runs.isEmpty) {
            return const Center(child: Text('Aucune course pour le moment.\nLance-toi !',
                textAlign: TextAlign.center));
          }
          final totalKm = runs.fold<double>(0, (s, r) => s + r.distanceM) / 1000;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${runs.length} courses · ${totalKm.toStringAsFixed(1)} km au total',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final r in runs)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.directions_run)),
                  title: Text('${(r.distanceM / 1000).toStringAsFixed(2)} km · ${formatDuration(r.movingTime)}'),
                  subtitle: Text('${DateFormat('EEE d MMM, HH:mm', 'fr_FR').format(r.startedAt)}'
                      ' · ${formatPace(r.avgSpeedMps)} /km'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(RunDetailScreen(runId: r.id!)),
                ),
            ],
          );
        },
      ),
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
