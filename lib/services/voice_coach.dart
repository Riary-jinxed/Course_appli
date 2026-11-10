import 'package:flutter_tts/flutter_tts.dart';

import 'geo.dart';

enum AnnounceMode { off, distance, time }

/// Annonces vocales régulières pendant la course (intervalle réglable).
class VoiceCoach {
  final FlutterTts _tts = FlutterTts();
  AnnounceMode mode;

  /// En km pour le mode distance, en minutes pour le mode temps.
  double interval;
  int _lastSlot = 0;

  VoiceCoach({this.mode = AnnounceMode.distance, this.interval = 1});

  Future<void> init() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    // Baisse le volume de la musique pendant l'annonce au lieu de la couper.
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.duckOthers]);
  }

  void reset() => _lastSlot = 0;

  Future<void> say(String text) => _tts.speak(text);

  /// Appelée à chaque mise à jour : parle quand un nouveau palier est franchi.
  Future<void> onProgress({
    required double distanceM,
    required Duration elapsed,
    required double avgSpeedMps,
  }) async {
    if (mode == AnnounceMode.off || interval <= 0) return;
    final value = mode == AnnounceMode.distance ? distanceM / 1000 : elapsed.inSeconds / 60;
    final slot = (value / interval).floor();
    if (slot <= _lastSlot) return;
    _lastSlot = slot;
    final km = (distanceM / 1000).toStringAsFixed(2).replaceAll('.', ',');
    final pace = formatPace(avgSpeedMps).replaceAll(':', ' minutes ');
    await say('$km kilomètres, en ${_spokenDuration(elapsed)}. Allure moyenne $pace par kilomètre.');
  }

  String _spokenDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final parts = <String>[
      if (h > 0) '$h heure${h > 1 ? 's' : ''}',
      if (m > 0) '$m minute${m > 1 ? 's' : ''}',
      if (h == 0) '$s seconde${s > 1 ? 's' : ''}',
    ];
    return parts.join(' ');
  }

  Future<void> stop() => _tts.stop();
}
