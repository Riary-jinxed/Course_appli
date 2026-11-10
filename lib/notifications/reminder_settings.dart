import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages des rappels, stockés sur le téléphone.
class ReminderSettings {
  /// Rappel "c'est l'heure de courir" certains jours (1 = lundi … 7 = dimanche).
  final bool runEnabled;
  final Set<int> runDays;
  final TimeOfDay runTime;

  /// Rappel le jour d'une séance du programme d'entraînement.
  final bool sessionEnabled;
  final TimeOfDay sessionTime;

  /// Rappels pour noter ses repas.
  final bool mealsEnabled;
  final List<TimeOfDay> mealTimes;

  /// Rappels pour boire de l'eau (toutes les 2 h de 9 h à 19 h).
  final bool waterEnabled;

  const ReminderSettings({
    this.runEnabled = false,
    this.runDays = const {2, 4, 7},
    this.runTime = const TimeOfDay(hour: 18, minute: 30),
    this.sessionEnabled = true,
    this.sessionTime = const TimeOfDay(hour: 8, minute: 0),
    this.mealsEnabled = false,
    this.mealTimes = const [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 12, minute: 30),
      TimeOfDay(hour: 20, minute: 0),
    ],
    this.waterEnabled = false,
  });

  ReminderSettings copyWith({
    bool? runEnabled,
    Set<int>? runDays,
    TimeOfDay? runTime,
    bool? sessionEnabled,
    TimeOfDay? sessionTime,
    bool? mealsEnabled,
    List<TimeOfDay>? mealTimes,
    bool? waterEnabled,
  }) =>
      ReminderSettings(
        runEnabled: runEnabled ?? this.runEnabled,
        runDays: runDays ?? this.runDays,
        runTime: runTime ?? this.runTime,
        sessionEnabled: sessionEnabled ?? this.sessionEnabled,
        sessionTime: sessionTime ?? this.sessionTime,
        mealsEnabled: mealsEnabled ?? this.mealsEnabled,
        mealTimes: mealTimes ?? this.mealTimes,
        waterEnabled: waterEnabled ?? this.waterEnabled,
      );

  static int _t(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _tod(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);

  Map<String, dynamic> toJson() => {
        'runEnabled': runEnabled,
        'runDays': runDays.toList(),
        'runTime': _t(runTime),
        'sessionEnabled': sessionEnabled,
        'sessionTime': _t(sessionTime),
        'mealsEnabled': mealsEnabled,
        'mealTimes': mealTimes.map(_t).toList(),
        'waterEnabled': waterEnabled,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) {
    const d = ReminderSettings();
    return ReminderSettings(
      runEnabled: j['runEnabled'] as bool? ?? d.runEnabled,
      runDays: (j['runDays'] as List?)?.cast<int>().toSet() ?? d.runDays,
      runTime: j['runTime'] == null ? d.runTime : _tod(j['runTime'] as int),
      sessionEnabled: j['sessionEnabled'] as bool? ?? d.sessionEnabled,
      sessionTime: j['sessionTime'] == null ? d.sessionTime : _tod(j['sessionTime'] as int),
      mealsEnabled: j['mealsEnabled'] as bool? ?? d.mealsEnabled,
      mealTimes: (j['mealTimes'] as List?)?.cast<int>().map(_tod).toList() ?? d.mealTimes,
      waterEnabled: j['waterEnabled'] as bool? ?? d.waterEnabled,
    );
  }

  static const _key = 'reminder_settings';

  static Future<ReminderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    return raw == null ? const ReminderSettings() : ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(toJson()));
  }
}
