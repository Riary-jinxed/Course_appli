import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_service.dart';
import 'reminder_settings.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ReminderSettings? _s;
  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _mealLabels = ['Petit-déjeuner', 'Déjeuner', 'Dîner'];

  @override
  void initState() {
    super.initState();
    ReminderSettings.load().then((s) => setState(() => _s = s));
  }

  Future<void> _update(ReminderSettings s) async {
    setState(() => _s = s);
    await s.save();
    if (!mounted) return;
    final n = context.read<NotificationService>();
    await n.requestPermission();
    await n.reschedule(s);
  }

  Future<TimeOfDay?> _pick(TimeOfDay t) => showTimePicker(context: context, initialTime: t);

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('Rappels')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Séances du programme'),
                  subtitle: Text('Le matin du jour prévu, à ${s.sessionTime.format(context)}'),
                  value: s.sessionEnabled,
                  onChanged: (v) => _update(s.copyWith(sessionEnabled: v)),
                ),
                if (s.sessionEnabled)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Heure du rappel de séance'),
                    trailing: Text(s.sessionTime.format(context)),
                    onTap: () async {
                      final t = await _pick(s.sessionTime);
                      if (t != null) _update(s.copyWith(sessionTime: t));
                    },
                  ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Rappel pour aller courir'),
                  subtitle: const Text('Les jours choisis, même sans programme'),
                  value: s.runEnabled,
                  onChanged: (v) => _update(s.copyWith(runEnabled: v)),
                ),
                if (s.runEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(spacing: 6, children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(_dayLabels[d - 1]),
                          selected: s.runDays.contains(d),
                          onSelected: (on) {
                            final days = {...s.runDays};
                            on ? days.add(d) : days.remove(d);
                            _update(s.copyWith(runDays: days));
                          },
                        ),
                    ]),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Heure'),
                    trailing: Text(s.runTime.format(context)),
                    onTap: () async {
                      final t = await _pick(s.runTime);
                      if (t != null) _update(s.copyWith(runTime: t));
                    },
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('Noter mes repas'),
                  subtitle: const Text('Un rappel à chaque repas'),
                  value: s.mealsEnabled,
                  onChanged: (v) => _update(s.copyWith(mealsEnabled: v)),
                ),
                if (s.mealsEnabled)
                  for (final (i, t) in s.mealTimes.indexed)
                    ListTile(
                      leading: const Icon(Icons.restaurant),
                      title: Text(i < _mealLabels.length ? _mealLabels[i] : 'Repas ${i + 1}'),
                      trailing: Text(t.format(context)),
                      onTap: () async {
                        final nt = await _pick(t);
                        if (nt == null) return;
                        final list = [...s.mealTimes]..[i] = nt;
                        _update(s.copyWith(mealTimes: list));
                      },
                    ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Boire de l\'eau'),
                  subtitle: const Text('Toutes les 2 heures, de 9 h à 19 h'),
                  value: s.waterEnabled,
                  onChanged: (v) => _update(s.copyWith(waterEnabled: v)),
                ),
              ],
            ),
    );
  }
}
