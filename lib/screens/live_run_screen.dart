import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controllers/run_tracker.dart';
import '../main.dart';
import '../records/records_repository.dart';
import '../safety/safety.dart';
import '../services/voice_coach.dart';
import '../shoes/shoes.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
import '../social/backup_service.dart';
import '../training/plan_repository.dart';
import '../voice/live_controls.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_tile.dart';
import 'run_detail_screen.dart';

class LiveRunScreen extends StatefulWidget {
  const LiveRunScreen({super.key});

  @override
  State<LiveRunScreen> createState() => _LiveRunScreenState();
}

class _LiveRunScreenState extends State<LiveRunScreen> {
  final _map = MapController();
  int _lastPointCount = 0;

  // --- Sécurité -----------------------------------------------------------
  late final LiveShare _live = context.read<LiveShare>();
  SafetySettings _safety = const SafetySettings();
  Timer? _guard;
  double _lastDist = 0;
  DateTime _lastMove = DateTime.now();
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = context.read<ProfileState>().profile!;
      final tracker = context.read<RunTracker>();
      await tracker.start(profile);
      _safety = await SafetySettings.load();
      _lastMove = DateTime.now();
      _guard = Timer.periodic(const Duration(seconds: 10), (_) => _checkSafety());
      if (_safety.shareOnStart && _safety.hasContact && tracker.state != TrackerState.idle) {
        await _shareLive(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _guard?.cancel();
    _live.stop();
    super.dispose();
  }

  /// Toutes les 10 s : envoie la position au proche et détecte une immobilité anormale.
  void _checkSafety() {
    final t = context.read<RunTracker>();
    final m = t.metrics;
    if (m == null) return;
    _live.update(points: m.points, distanceM: m.distanceM, elapsed: t.elapsed);
    if (t.state != TrackerState.running) {
      _lastMove = DateTime.now();
      return;
    }
    if (m.distanceM - _lastDist > 15) {
      _lastDist = m.distanceM;
      _lastMove = DateTime.now();
    }
    final still = DateTime.now().difference(_lastMove);
    if (_safety.immobileAlert && !_alertOpen && still >= Duration(minutes: _safety.immobileMinutes)) {
      _immobileAlert();
    }
  }

  Future<void> _immobileAlert() async {
    _alertOpen = true;
    final coach = context.read<VoiceCoach>();
    await coach.say('Tu ne bouges plus depuis un moment. Tout va bien ? Touche l\'écran pour confirmer.');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CountdownDialog(seconds: 60),
    );
    _alertOpen = false;
    _lastMove = DateTime.now();
    if (ok == false) await _sos(auto: true);
  }

  String _positionText() {
    final pts = context.read<RunTracker>().metrics?.points ?? const [];
    return pts.isEmpty ? '' : ' Position : ${mapsLink(pts.last.lat, pts.last.lng)}';
  }

  Future<void> _shareLive({bool auto = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_safety.hasContact) {
      messenger.showSnackBar(const SnackBar(content: Text('Ajoute un contact d\'urgence dans Profil > Sécurité.')));
      return;
    }
    final name = context.read<ProfileState>().profile?.name ?? '';
    final link = _live.link ?? await _live.start(name);
    if (link == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Suivi en direct indisponible (connecte-toi dans l\'onglet Social). Envoi de la position actuelle.')));
    }
    final body = link != null
        ? '🏃 Je pars courir ! Tu peux suivre ma position en direct ici : $link'
        : '🏃 Je pars courir.${_positionText()}';
    await LiveShare.sms(_safety.contactPhone, body);
  }

  Future<void> _sos({bool auto = false}) async {
    if (!auto) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Envoyer une alerte SOS ?'),
          content: Text(_safety.hasContact
              ? 'Un SMS avec ta position sera préparé pour ${_safety.contactName.isEmpty ? 'ton contact' : _safety.contactName}.'
              : 'Aucun contact d\'urgence : tu pourras appeler le 112.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('SOS'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _live.markSos();
    if (_safety.hasContact) {
      final link = _live.link;
      await LiveShare.sms(
        _safety.contactPhone,
        '🚨 SOS : j\'ai peut-être un problème pendant ma course.${_positionText()}'
        '${link == null ? '' : ' Suivi en direct : $link'}',
      );
    } else {
      await LiveShare.call('112');
    }
  }

  Future<void> _finish(RunTracker t) async {
    final plans = context.read<PlanRepository>();
    final runs = context.read<RunRepository>();
    final backup = context.read<BackupService>();
    final records = context.read<RecordsRepository>();
    final shoes = context.read<ShoeRepository>();
    final coach = context.read<VoiceCoach>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Terminer la course ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminer')),
        ],
      ),
    );
    if (ok != true) return;
    final id = await t.stop();
    _guard?.cancel();
    await _live.stop();
    if (id != null) {
      final shoe = await shoes.assignDefault(id);
      final run = await runs.get(id);
      if (run != null) backup.backup(run);
      if (run != null) {
        final beaten = await records.process(id, run);
        if (beaten.isNotEmpty) {
          final what = beaten.join(', ');
          messenger.showSnackBar(SnackBar(content: Text('🏆 Nouveau record : $what !')));
          coach.say('Bravo, nouveau record personnel sur $what !');
        }
      }
      final warn = shoe?.wearWarning;
      if (warn != null) messenger.showSnackBar(SnackBar(content: Text('👟 ${shoe!.name} : $warn')));
      final session = run == null ? null : await plans.matchRun(id, run);
      if (session != null) {
        messenger.showSnackBar(SnackBar(content: Text('Séance validée : ${session.type.label} ✓')));
      }
    }
    if (!mounted) return;
    if (id == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Course trop courte, non enregistrée.')));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => RunDetailScreen(runId: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<RunTracker>();
    final m = t.metrics;
    final points = m?.points ?? const [];

    // Recentre la carte sur le coureur à chaque nouveau point.
    if (points.length != _lastPointCount && points.isNotEmpty) {
      _lastPointCount = points.length;
      final last = points.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _map.move(LatLng(last.lat, last.lng), _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
        } catch (_) {}
      });
    }

    return PopScope(
      canPop: t.state == TrackerState.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(t);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.state == TrackerState.paused ? 'En pause' : 'Course en cours'),
          actions: [
            IconButton(
              icon: Icon(_live.active ? Icons.share_location : Icons.location_on_outlined),
              tooltip: 'Partager ma position avec un proche',
              onPressed: _shareLive,
            ),
            TextButton(
              onPressed: _sos,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Column(
          children: [
            if (t.error != null)
              MaterialBanner(content: Text(t.error!), actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ]),
            Expanded(
              flex: 4,
              child: RouteMap(points: points, checkpoints: t.checkpoints, follow: true, controller: _map),
            ),
            const SizedBox(height: 8),
            const LiveControls(),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatTile(label: 'Temps', value: formatDuration(t.elapsed), large: true),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      StatTile(
                          label: 'Distance',
                          value: ((m?.distanceM ?? 0) / 1000).toStringAsFixed(2),
                          unit: 'km'),
                      StatTile(label: 'Allure', value: formatPace(m?.currentSpeedMps ?? 0), unit: '/km'),
                      StatTile(
                          label: 'Vitesse moy.',
                          value: ((m?.avgSpeedMps ?? 0) * 3.6).toStringAsFixed(1),
                          unit: 'km/h'),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      StatTile(label: 'Calories', value: (m?.calories ?? 0).round().toString(), unit: 'kcal'),
                      StatTile(
                          label: 'D+ / D-',
                          value: '${(m?.elevationGainM ?? 0).round()} / ${(m?.elevationLossM ?? 0).round()}',
                          unit: 'm'),
                      StatTile(label: 'Pas', value: t.steps.toString()),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flag),
                    label: Text('Checkpoint (${t.checkpoints.length})'),
                    onPressed: t.state == TrackerState.running ? t.addCheckpoint : null,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  iconSize: 32,
                  icon: Icon(t.state == TrackerState.paused ? Icons.play_arrow : Icons.pause),
                  onPressed: t.state == TrackerState.idle
                      ? null
                      : (t.state == TrackerState.paused ? t.resume : t.pause),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  iconSize: 32,
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.stop),
                  onPressed: t.state == TrackerState.idle ? null : () => _finish(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Tout va bien ?" avec compte à rebours. Renvoie true si l'utilisateur répond,
/// false si le temps est écoulé (l'alerte part alors).
class _CountdownDialog extends StatefulWidget {
  final int seconds;
  const _CountdownDialog({required this.seconds});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        Navigator.pop(context, false);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Tout va bien ?'),
        content: Text('Tu es immobile depuis plusieurs minutes. Sans réponse, ton contact '
            'd\'urgence sera alerté dans $_left s.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Alerter maintenant')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tout va bien')),
        ],
      );
}
