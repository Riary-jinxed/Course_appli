import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/run.dart';
import '../services/run_repository.dart';
import 'social_repository.dart';

/// Sauvegarde les courses (tracé compris) dans Supabase, privées à chacun,
/// et les restaure sur un nouveau téléphone ou après une réinstallation.
///
/// Une course est identifiée par son heure de départ (en ms).
class BackupService extends ChangeNotifier {
  final RunRepository runs;
  final SocialRepository social;

  BackupService(this.runs, this.social);

  bool syncing = false;
  DateTime? lastSync;
  String? lastError;

  SupabaseClient get _db => Supabase.instance.client;
  bool get available => SupabaseConfig.enabled && social.userId != null;

  /// Écoute les connexions pour synchroniser automatiquement.
  void start() {
    if (!SupabaseConfig.enabled) return;
    social.authChanges.listen((s) {
      if (s.event == AuthChangeEvent.signedIn || s.event == AuthChangeEvent.initialSession) {
        if (s.session != null) sync();
      }
    });
  }

  Future<void> backup(Run run) async {
    if (!available) return;
    try {
      await _db.from('run_backups').upsert({
        'user_id': social.userId,
        'started_at_ms': run.startedAt.millisecondsSinceEpoch,
        'data': run.toBackupJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Pas de réseau : la course sera envoyée à la prochaine synchro.
      lastError = '$e';
    }
  }

  Future<void> remove(DateTime startedAt) async {
    if (!available) return;
    try {
      await _db
          .from('run_backups')
          .delete()
          .eq('user_id', social.userId!)
          .eq('started_at_ms', startedAt.millisecondsSinceEpoch);
    } catch (e) {
      lastError = '$e';
    }
  }

  /// Envoie les courses absentes du cloud et récupère celles absentes du téléphone.
  /// Renvoie le nombre de courses restaurées.
  Future<int> sync() async {
    if (!available || syncing) return 0;
    syncing = true;
    lastError = null;
    notifyListeners();
    var restored = 0;
    try {
      final remoteRows = await _db.from('run_backups').select('started_at_ms').eq('user_id', social.userId!);
      final remote = {for (final r in remoteRows) (r['started_at_ms'] as num).toInt()};
      final local = await runs.list();
      final localKeys = {for (final r in local) r.startedAt.millisecondsSinceEpoch};

      for (final r in local.where((r) => !remote.contains(r.startedAt.millisecondsSinceEpoch))) {
        final full = await runs.get(r.id!);
        if (full != null) await backup(full);
      }

      final missing = remote.difference(localKeys).toList();
      // Par paquets pour ne pas tout télécharger d'un coup.
      for (var i = 0; i < missing.length; i += 20) {
        final batch = missing.sublist(i, (i + 20).clamp(0, missing.length));
        final rows = await _db
            .from('run_backups')
            .select('data')
            .eq('user_id', social.userId!)
            .inFilter('started_at_ms', batch);
        for (final row in rows) {
          await runs.save(Run.fromBackupJson((row['data'] as Map).cast<String, dynamic>()));
          restored++;
        }
      }
      lastSync = DateTime.now();
    } catch (e) {
      lastError = '$e';
    } finally {
      syncing = false;
      notifyListeners();
    }
    return restored;
  }
}
