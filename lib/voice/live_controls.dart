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
  String? _heard;

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
