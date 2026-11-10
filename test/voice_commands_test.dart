import 'package:course_appli/voice/voice_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commandes vocales en français', () {
    final cases = {
      'checkpoint': VoiceCommand.checkpoint,
      'Marque un point ici': VoiceCommand.checkpoint,
      'pause': VoiceCommand.pause,
      'on reprend, reprendre': VoiceCommand.resume,
      'continue': VoiceCommand.resume,
      'où j\'en suis': VoiceCommand.stats,
      'donne-moi les stats': VoiceCommand.stats,
      'quelle allure': VoiceCommand.stats,
      'musique suivante': VoiceCommand.musicNext,
      'chanson suivante': VoiceCommand.musicNext,
      'passe': VoiceCommand.musicNext,
      'chanson précédente': VoiceCommand.musicPrevious,
      'pause musique': VoiceCommand.musicPause,
      'coupe la musique': VoiceCommand.musicPause,
      'remets la musique': VoiceCommand.musicPlay,
      'motive-moi': VoiceCommand.motivation,
    };
    for (final e in cases.entries) {
      expect(parseVoiceCommand(e.key), e.value, reason: e.key);
    }
    expect(parseVoiceCommand('bonjour'), isNull);
  });
}
