import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/run_tracker.dart';
import '../music/spotify_controller.dart';
import '../services/voice_coach.dart';
import 'voice_commands.dart';

/// Barre musique + bouton micro affichés pendant la course.
class LiveControls extends StatefulWidget {
  const LiveControls({super.key});

  @override
  State<LiveControls> createState() => _LiveControlsState();
}

class _LiveControlsState extends State<LiveControls> {
  final _voice = VoiceListener();
  bool _listening = false;
  bool _handsFree = false;
  String? _heard;

  @override
  void dispose() {
    // Fin de course : le micro s'arrête, il n'écoute jamais en dehors d'une course.
    _handsFree = false;
    _voice.stop();
    super.dispose();
  }

  /// Mode mains libres : réécoute en boucle tant que la course n'est pas terminée.
  void _loop() {
    if (!_handsFree || !mounted) return;
    if (context.read<RunTracker>().state == TrackerState.idle) return;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_handsFree && mounted && !_voice.listening) _listen();
    });
  }

  Future<void> _listen() async {
    final tracker = context.read<RunTracker>();
    final coach = context.read<VoiceCoach>();
    final music = context.read<SpotifyController>();
    setState(() {
      _listening = true;
      _heard = null;
    });
    await _voice.listen((cmd, heard) async {
      if (!mounted) return;
      // En mains libres, le silence n'est pas une erreur : on réécoute.
      if (_handsFree && cmd == null) {
        setState(() => _listening = false);
        _loop();
        return;
      }
      setState(() {
        _listening = false;
        _heard = heard.isEmpty ? null : heard;
      });
      final m = tracker.metrics;
      switch (cmd) {
        case VoiceCommand.checkpoint:
          tracker.addCheckpoint();
        case VoiceCommand.pause:
          tracker.pause();
        case VoiceCommand.resume:
          tracker.resume();
        case VoiceCommand.stats:
          await coach.announceStats(
            distanceM: m?.distanceM ?? 0,
            elapsed: tracker.elapsed,
            avgSpeedMps: m?.avgSpeedMps ?? 0,
            calories: m?.calories,
          );
        case VoiceCommand.motivation:
          await coach.motivate();
        case VoiceCommand.musicNext:
          await music.next();
        case VoiceCommand.musicPrevious:
          await music.previous();
        case VoiceCommand.musicPause:
          await music.pause();
        case VoiceCommand.musicPlay:
          await music.play();
        case null:
          await coach.say(heard.isEmpty
              ? 'Je n\'ai rien entendu.'
              : 'Je n\'ai pas compris. Dis checkpoint, pause, stats ou musique suivante.');
      }
      _loop();
    });
    if (mounted && !_voice.listening) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<SpotifyController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
          child: music.connected
              ? Row(children: [
                  IconButton(icon: const Icon(Icons.skip_previous), onPressed: music.previous),
                  IconButton.filledTonal(
                    icon: Icon(music.paused ? Icons.play_arrow : Icons.pause),
                    onPressed: music.playPause,
                  ),
                  IconButton(icon: const Icon(Icons.skip_next), onPressed: music.next),
                  Expanded(
                    child: Text(
                      music.track == null ? 'Spotify' : '${music.track}\n${music.artist ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ])
              : TextButton.icon(
                  icon: const Icon(Icons.music_note, color: Color(0xFF1DB954)),
                  label: Text(music.connecting
                      ? 'Connexion…'
                      : (music.error != null ? 'Spotify indisponible' : 'Connecter Spotify')),
                  onPressed: music.connecting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (!await music.connect() && music.error != null) {
                            messenger.showSnackBar(SnackBar(content: Text(music.error!)));
                          }
                        },
                ),
        ),
        IconButton(
          tooltip: _handsFree ? 'Mains libres activé' : 'Activer les mains libres',
          isSelected: _handsFree,
          icon: const Icon(Icons.record_voice_over_outlined),
          selectedIcon: const Icon(Icons.record_voice_over),
          onPressed: () {
            setState(() => _handsFree = !_handsFree);
            final coach = context.read<VoiceCoach>();
            if (_handsFree) {
              coach.say('Mains libres activé. Je t\'écoute pendant la course.');
              if (!_voice.listening) _listen();
            } else {
              _voice.stop();
              coach.say('Mains libres désactivé.');
            }
          },
        ),
        Tooltip(
          message: _heard == null ? 'Commande vocale' : 'Entendu : « $_heard »',
          child: FloatingActionButton.small(
            heroTag: 'mic',
            backgroundColor: _listening ? Colors.red : null,
            onPressed: _listening ? _voice.stop : _listen,
            child: Icon(_listening ? Icons.hearing : Icons.mic),
          ),
        ),
      ]),
    );
  }
}
