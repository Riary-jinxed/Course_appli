import 'package:course_appli/update/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lecture de version.json publié par la CI', () {
    final info = ReleaseInfo.tryParse(
        '{"build": 42, "commit": "abc1234", "date": "2026-11-10T14:00:00Z", "notes": "Bouton mise à jour", "size": 1234}');
    expect(info, isNotNull);
    expect(info!.build, 42);
    expect(info.commit, 'abc1234');
    expect(info.notes, 'Bouton mise à jour');
    expect(info.size, 1234);
    expect(info.date!.toUtc(), DateTime.utc(2026, 11, 10, 14));
  });

  test('comparaison avec la version installée', () {
    const info = ReleaseInfo(build: 42);
    expect(info.isNewerThan(41), isTrue);
    expect(info.isNewerThan(42), isFalse);
    expect(info.isNewerThan(50), isFalse);
  });

  test('fichier invalide ou incomplet', () {
    expect(ReleaseInfo.tryParse('pas du json'), isNull);
    expect(ReleaseInfo.tryParse('{"commit": "abc"}'), isNull);
    expect(ReleaseInfo.tryParse('[1, 2]'), isNull);
    expect(ReleaseInfo.tryParse('{"build": "7", "notes": "  "}')!.build, 7);
    expect(ReleaseInfo.tryParse('{"build": "7", "notes": "  "}')!.notes, isNull);
  });
}
