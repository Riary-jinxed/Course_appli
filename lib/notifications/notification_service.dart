import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../training/models.dart';
import '../training/plan_repository.dart';
import 'reminder_settings.dart';

/// Programme les rappels locaux (sans serveur) : courses, séances, repas, eau.
class NotificationService {
  final PlanRepository plans;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  NotificationService(this.plans);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rappels',
      'Rappels',
      channelDescription: 'Rappels de course, de séance et de repas',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  tz.TZDateTime _next(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.isBefore(now) || (weekday != null && t.weekday != weekday)) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, hour, minute);
    }
    return t;
  }

  Future<void> _schedule(int id, String title, String body, tz.TZDateTime at, [DateTimeComponents? repeat]) =>
      _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: _details,
        // Inexact : pas besoin de la permission "alarmes exactes", quelques minutes d'écart possibles.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeat,
      );

  /// Annule tout et reprogramme selon les réglages et le programme en cours.
  Future<void> reschedule([ReminderSettings? settings]) async {
    if (!_ready) return;
    final s = settings ?? await ReminderSettings.load();
    await _plugin.cancelAll();

    if (s.runEnabled) {
      for (final d in s.runDays) {
        await _schedule(1000 + d, "C'est l'heure de courir 🏃", 'Enfile tes baskets, même 20 minutes ça compte !',
            _next(s.runTime.hour, s.runTime.minute, weekday: d), DateTimeComponents.dayOfWeekAndTime);
      }
    }

    if (s.mealsEnabled) {
      const labels = ['petit-déjeuner', 'déjeuner', 'dîner', 'collation'];
      for (final (i, t) in s.mealTimes.indexed) {
        await _schedule(2000 + i, 'Repas 🍽️', 'Pense à noter ton ${labels[i % labels.length]} dans l\'onglet Nutrition.',
            _next(t.hour, t.minute), DateTimeComponents.time);
      }
    }

    if (s.waterEnabled) {
      for (var h = 9; h <= 19; h += 2) {
        await _schedule(2500 + h, 'Hydratation 💧', 'Un grand verre d\'eau ?', _next(h, 0), DateTimeComponents.time);
      }
    }

    if (s.sessionEnabled) {
      final now = tz.TZDateTime.now(tz.local);
      final sessions = await plans.upcomingSessions(days: 30);
      for (final ses in sessions) {
        final at = tz.TZDateTime(tz.local, ses.date.year, ses.date.month, ses.date.day,
            s.sessionTime.hour, s.sessionTime.minute);
        if (at.isBefore(now)) continue;
        final title = ses.type == SessionType.race
            ? "C'est le jour J ! 🏅"
            : 'Séance du jour : ${ses.type.label}';
        await _schedule(3000 + (ses.id! % 100000), title, ses.description, at);
      }
    }
  }
}
