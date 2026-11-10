import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Météo actuelle et des prochaines heures (Open-Meteo, gratuit, sans clé).
class Weather {
  final double temp;
  final double feelsLike;
  final double windKmh;
  final int humidity;
  final int code; // code météo WMO
  final double precipitationMm;

  /// Probabilité de pluie max sur les 3 prochaines heures (%).
  final int rainChance3h;
  final bool isDay;
  final double uvIndex;

  const Weather({
    required this.temp,
    required this.feelsLike,
    required this.windKmh,
    required this.humidity,
    required this.code,
    this.precipitationMm = 0,
    this.rainChance3h = 0,
    this.isDay = true,
    this.uvIndex = 0,
  });

  String get description => switch (code) {
        0 => isDay ? '☀️ Ciel dégagé' : '🌙 Ciel dégagé',
        1 || 2 => '⛅ Peu nuageux',
        3 => '☁️ Couvert',
        45 || 48 => '🌫️ Brouillard',
        51 || 53 || 55 || 56 || 57 => '🌦️ Bruine',
        61 || 63 || 80 || 81 => '🌧️ Pluie',
        65 || 82 => '🌧️ Forte pluie',
        66 || 67 => '🧊 Pluie verglaçante',
        71 || 73 || 75 || 77 || 85 || 86 => '❄️ Neige',
        95 || 96 || 99 => '⛈️ Orage',
        _ => '🌡️ Météo',
      };

  bool get raining => [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code) || precipitationMm > 0.2;
  bool get storm => code >= 95;
  bool get icy => [56, 57, 66, 67, 71, 73, 75, 77, 85, 86].contains(code);

  static Future<Weather> fetch(double lat, double lng) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(3),
      'longitude': lng.toStringAsFixed(3),
      'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,'
          'wind_speed_10m,is_day,uv_index',
      'hourly': 'precipitation_probability',
      'forecast_hours': '3',
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Météo indisponible (${res.statusCode})');
    return Weather.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  factory Weather.fromJson(Map<String, dynamic> j) {
    final c = j['current'] as Map<String, dynamic>;
    final rain = ((j['hourly'] as Map?)?['precipitation_probability'] as List?)?.whereType<num>() ?? const <num>[];
    double d(String k) => (c[k] as num?)?.toDouble() ?? 0;
    return Weather(
      temp: d('temperature_2m'),
      feelsLike: d('apparent_temperature'),
      windKmh: d('wind_speed_10m'),
      humidity: (c['relative_humidity_2m'] as num?)?.round() ?? 0,
      code: (c['weather_code'] as num?)?.toInt() ?? 0,
      precipitationMm: d('precipitation'),
      rainChance3h: rain.isEmpty ? 0 : rain.reduce((a, b) => a > b ? a : b).round(),
      isDay: (c['is_day'] as num?) != 0,
      uvIndex: d('uv_index'),
    );
  }

  /// Météo à la position actuelle (position approximative suffisante).
  static Future<Weather> here() async {
    var pos = await Geolocator.getLastKnownPosition();
    pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)));
    return fetch(pos.latitude, pos.longitude);
  }
}

/// Conseils de tenue et de sécurité selon la météo (température ressentie en course :
/// on a environ 10 °C de plus qu'à l'arrêt après quelques minutes).
List<String> outfitAdvice(Weather w) {
  final t = w.feelsLike;
  final tips = <String>[
    if (t >= 25) '🩳 Short + débardeur léger, casquette'
    else if (t >= 15) '👕 Short + t-shirt technique'
    else if (t >= 8) '👕 Corsaire ou short + manches longues fines'
    else if (t >= 2) '🧥 Collant + manches longues + coupe-vent léger, gants fins'
    else if (t >= -5) '🧤 Collant thermique, 2 couches en haut, bonnet et gants'
    else '🥶 Très froid : couches thermiques, cache-cou, bonnet, gants ; sortie courte conseillée',
    if (w.raining || w.rainChance3h >= 60) '🌧️ Veste imperméable légère, casquette pour la visière',
    if (w.windKmh >= 30) '💨 Vent fort (${w.windKmh.round()} km/h) : coupe-vent, pars face au vent pour le rentrer dos au vent',
    if (t >= 25 || (w.uvIndex >= 6 && w.isDay)) '🧴 Crème solaire et lunettes, pars tôt ou tard',
    if (t >= 22) '💧 Emporte de l\'eau, ralentis l\'allure de 10 à 20 s/km',
    if (!w.isDay) '🔦 Frontale et vêtement réfléchissant',
    if (w.icy) '⚠️ Risque de verglas : chaussures à bonne accroche, évite les descentes',
    if (w.storm) '⛔ Orage : mieux vaut reporter la sortie ou courir sur tapis',
    if (w.humidity >= 85 && t >= 20) '🥵 Air très humide : effort plus dur, écoute tes sensations',
  ];
  return tips;
}
