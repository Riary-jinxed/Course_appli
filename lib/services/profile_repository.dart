import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'voice_coach.dart';

class ProfileRepository {
  static const _key = 'user_profile';

  Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(p.toJson()));
  }
}

extension CoachSettingsStore on ProfileRepository {
  Future<(AnnounceMode, double)> loadCoachSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = AnnounceMode.values.firstWhere(
      (m) => m.name == prefs.getString('coach_mode'),
      orElse: () => AnnounceMode.distance,
    );
    return (mode, prefs.getDouble('coach_interval') ?? 1.0);
  }

  Future<void> saveCoachSettings(AnnounceMode mode, double interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coach_mode', mode.name);
    await prefs.setDouble('coach_interval', interval);
  }
}
