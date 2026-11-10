import 'package:speech_to_text/speech_to_text.dart';

enum VoiceCommand {
  checkpoint,
  pause,
  resume,
  stats,
  musicNext,
  musicPrevious,
  musicPause,
  musicPlay,
  motivation,
}

/// Reconnaît une commande dans une phrase en français. Renvoie null si rien.
VoiceCommand? parseVoiceCommand(String text) {
  final t = text
      .toLowerCase()
      .replaceAll(RegExp('[éèê]'), 'e')
      .replaceAll(RegExp('[àâ]'), 'a')
      .replaceAll(RegExp('[ùû]'), 'u')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(' +'), ' ');
  bool has(List<String> words) => words.any((w) => RegExp('\\b$w\\b').hasMatch(t));

  final music = has(['musique', 'chanson', 'morceau', 'titre', 'spotify', 'son']);
  if (has(['suivant', 'suivante', 'next', 'passe', 'zappe', 'change'])) return VoiceCommand.musicNext;
  if (has(['precedent', 'precedente', 'avant', 'retour'])) return VoiceCommand.musicPrevious;
  if (music && has(['pause', 'stop', 'arrete', 'coupe'])) return VoiceCommand.musicPause;
  if (music && has(['play', 'lecture', 'lance', 'remets', 'joue', 'mets'])) return VoiceCommand.musicPlay;
  if (has(['checkpoint', 'check', 'point', 'marque', 'marquer', 'repere', 'drapeau'])) return VoiceCommand.checkpoint;
  if (has(['reprendre', 'reprends', 'reprise', 'continue', 'continuer', 'repart', 'go'])) return VoiceCommand.resume;
  if (has(['pause'])) return VoiceCommand.pause;
  if (has(['stats', 'statistiques', 'bilan', 'distance', 'allure', 'temps', 'combien', 'ou j en suis'])) {
    return VoiceCommand.stats;
  }
  if (has(['motivation', 'motive', 'encourage', 'courage', 'aide'])) return VoiceCommand.motivation;
  return null;
}

/// Écoute une commande (quelques secondes) via la reconnaissance vocale du téléphone.
class VoiceListener {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  bool get listening => _stt.isListening;

  Future<bool> init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(onError: (_) {});
    return _ready;
  }

  /// Appelle [onResult] avec la commande reconnue (ou null) et la phrase entendue.
  Future<void> listen(void Function(VoiceCommand? cmd, String heard) onResult) async {
    if (!await init()) {
      onResult(null, '');
      return;
    }
    var done = false;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 6),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
        contextualPhrases: const ['checkpoint', 'pause', 'reprendre', 'stats', 'musique suivante', 'chanson précédente'],
      ),
      onResult: (r) {
        if (done) return;
        final cmd = parseVoiceCommand(r.recognizedWords);
        // On réagit dès qu'une commande est comprise, sans attendre la fin.
        if (cmd != null || r.finalResult) {
          done = true;
          _stt.stop();
          onResult(cmd, r.recognizedWords);
        }
      },
    );
  }

  Future<void> stop() => _stt.stop();
}
