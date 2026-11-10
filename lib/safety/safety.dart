import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/run.dart';
import '../social/social_repository.dart';

class SafetySettings {
  final String contactName;
  final String contactPhone;

  /// Envoyer le lien de suivi en direct au proche à chaque départ.
  final bool shareOnStart;

  /// Alerter si on ne bouge plus pendant [immobileMinutes] alors que la course n'est pas en pause.
  final bool immobileAlert;
  final int immobileMinutes;

  const SafetySettings({
    this.contactName = '',
    this.contactPhone = '',
    this.shareOnStart = false,
    this.immobileAlert = true,
    this.immobileMinutes = 5,
  });

  bool get hasContact => contactPhone.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'contactName': contactName,
        'contactPhone': contactPhone,
        'shareOnStart': shareOnStart,
        'immobileAlert': immobileAlert,
        'immobileMinutes': immobileMinutes,
      };

  factory SafetySettings.fromJson(Map<String, dynamic> j) => SafetySettings(
        contactName: j['contactName'] as String? ?? '',
        contactPhone: j['contactPhone'] as String? ?? '',
        shareOnStart: j['shareOnStart'] as bool? ?? false,
        immobileAlert: j['immobileAlert'] as bool? ?? true,
        immobileMinutes: j['immobileMinutes'] as int? ?? 5,
      );

  static Future<SafetySettings> load() async {
    final raw = (await SharedPreferences.getInstance()).getString('safety');
    return raw == null ? const SafetySettings() : SafetySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() async => (await SharedPreferences.getInstance()).setString('safety', jsonEncode(toJson()));
}

/// Garde un échantillon d'au plus [max] points du tracé (pour le suivi en direct).
List<List<double>> downsampleTrail(List<TrackPoint> points, {int max = 300}) {
  if (points.isEmpty) return [];
  final step = (points.length / max).ceil().clamp(1, points.length);
  final out = <List<double>>[
    for (var i = 0; i < points.length; i += step) [_r(points[i].lat), _r(points[i].lng)],
  ];
  final last = points.last;
  if (out.last[0] != _r(last.lat) || out.last[1] != _r(last.lng)) out.add([_r(last.lat), _r(last.lng)]);
  return out;
}

double _r(double v) => (v * 1e5).round() / 1e5;

String mapsLink(double lat, double lng) =>
    'https://maps.google.com/?q=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

/// Partage de la position en direct (Supabase) + SMS au proche.
class LiveShare {
  static const viewerUrl = 'https://riary-jinxed.github.io/Course_appli/live/';

  final SocialRepository social;
  LiveShare(this.social);

  String? _token;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  bool get active => _token != null;
  String? get link => _token == null ? null : '$viewerUrl?t=$_token';
  bool get available => SupabaseConfig.enabled && social.userId != null;

  SupabaseClient get _db => Supabase.instance.client;

  /// Démarre une session de suivi. Renvoie le lien, ou null si non connecté.
  Future<String?> start(String name) async {
    if (!available) return null;
    try {
      final row = await _db
          .from('live_sessions')
          .insert({'user_id': social.userId, 'display_name': name})
          .select('token')
          .single();
      _token = row['token'] as String;
      return link;
    } catch (_) {
      return null;
    }
  }

  /// Envoie la position (au plus toutes les 20 s, sauf si [force]).
  Future<void> update({
    required List<TrackPoint> points,
    required double distanceM,
    required Duration elapsed,
    bool force = false,
  }) async {
    final t = _token;
    if (t == null || points.isEmpty) return;
    if (!force && DateTime.now().difference(_lastPush) < const Duration(seconds: 20)) return;
    _lastPush = DateTime.now();
    try {
      await _db.from('live_sessions').update({
        'lat': points.last.lat,
        'lng': points.last.lng,
        'distance_m': distanceM,
        'elapsed_s': elapsed.inSeconds,
        'trail': downsampleTrail(points),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('token', t);
    } catch (_) {
      // Pas de réseau : on réessaiera au prochain point.
    }
  }

  Future<void> markSos() async {
    final t = _token;
    if (t == null) return;
    try {
      await _db.from('live_sessions').update({'sos': true}).eq('token', t);
    } catch (_) {}
  }

  Future<void> stop() async {
    final t = _token;
    _token = null;
    if (t == null) return;
    try {
      await _db.from('live_sessions').update({'active': false}).eq('token', t);
    } catch (_) {}
  }

  /// Ouvre l'appli SMS avec le message prérempli (l'utilisateur n'a qu'à envoyer).
  static Future<bool> sms(String phone, String body) => launchUrl(
        Uri(scheme: 'sms', path: phone.replaceAll(' ', ''), queryParameters: {'body': body}),
      );

  static Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
}
