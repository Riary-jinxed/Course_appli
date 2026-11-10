import 'package:course_appli/weather/weather.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lecture de la réponse Open-Meteo', () {
    final w = Weather.fromJson({
      'current': {
        'temperature_2m': 6.4,
        'apparent_temperature': 3.1,
        'relative_humidity_2m': 80,
        'precipitation': 0.0,
        'weather_code': 3,
        'wind_speed_10m': 12.0,
        'is_day': 1,
        'uv_index': 1.0,
      },
      'hourly': {'precipitation_probability': [10, 70, null]},
    });
    expect(w.temp, 6.4);
    expect(w.rainChance3h, 70);
    expect(w.description, contains('Couvert'));
    final tips = outfitAdvice(w);
    expect(tips.first, contains('Collant'));
    expect(tips.any((t) => t.contains('imperméable')), isTrue);
  });

  test('chaleur, nuit, orage', () {
    const hot = Weather(temp: 30, feelsLike: 32, windKmh: 5, humidity: 50, code: 0, uvIndex: 8);
    expect(outfitAdvice(hot).any((t) => t.contains('Crème solaire')), isTrue);
    const night = Weather(temp: 10, feelsLike: 10, windKmh: 5, humidity: 50, code: 0, isDay: false);
    expect(outfitAdvice(night).any((t) => t.contains('Frontale')), isTrue);
    const storm = Weather(temp: 18, feelsLike: 18, windKmh: 40, humidity: 90, code: 95);
    final s = outfitAdvice(storm);
    expect(s.any((t) => t.contains('Orage')), isTrue);
    expect(s.any((t) => t.contains('Vent fort')), isTrue);
  });
}
