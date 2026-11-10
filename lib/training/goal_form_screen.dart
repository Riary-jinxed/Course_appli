import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../notifications/notification_service.dart';
import 'models.dart';
import 'plan_repository.dart';

class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({super.key});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  static const _presets = {'5 km': 5.0, '10 km': 10.0, 'Semi': 21.1, 'Marathon': 42.195};

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _distance = TextEditingController(text: '10');
  final _target = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 70));
  int _spw = 3;
  bool _saving = false;

  /// "50", "50:00" ou "1:45:00" → durée.
  Duration? _parseTime(String s) {
    final parts = s.trim().split(RegExp('[:h]')).where((p) => p.isNotEmpty).map(int.tryParse).toList();
    if (parts.isEmpty || parts.contains(null)) return null;
    final p = parts.cast<int>();
    return switch (p.length) {
      1 => Duration(minutes: p[0]),
      2 => Duration(minutes: p[0], seconds: p[1]),
      3 => Duration(hours: p[0], minutes: p[1], seconds: p[2]),
      _ => null,
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final km = double.parse(_distance.text.replaceAll(',', '.'));
    final goal = RaceGoal(
      name: _name.text.trim().isEmpty ? '${_distance.text} km' : _name.text.trim(),
      distanceKm: km,
      date: _date,
      targetTime: _target.text.trim().isEmpty ? null : _parseTime(_target.text),
      sessionsPerWeek: _spw,
      createdAt: DateTime.now(),
    );
    final notifications = context.read<NotificationService>();
    await context.read<PlanRepository>().createGoal(goal);
    notifications.reschedule();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final weeks = (_date.difference(DateTime.now()).inDays / 7).ceil();
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel objectif')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: "Nom de l'épreuve", hintText: 'Ex. 10 km de Paris'),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              for (final e in _presets.entries)
                ChoiceChip(
                  label: Text(e.key),
                  selected: _distance.text == e.value.toString() || _distance.text == e.value.toInt().toString(),
                  onSelected: (_) => setState(() => _distance.text =
                      e.value == e.value.roundToDouble() ? e.value.toInt().toString() : e.value.toString()),
                ),
            ]),
            TextFormField(
              controller: _distance,
              decoration: const InputDecoration(labelText: 'Distance', suffixText: 'km'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                return d == null || d < 1 || d > 200 ? 'Distance invalide' : null;
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Date de l'épreuve"),
              subtitle: Text('${DateFormat.yMMMMEEEEd('fr_FR').format(_date)} · dans $weeks semaines'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            if (weeks < 6)
              const Text(
                "Moins de 6 semaines : le programme sera court, l'idée est surtout d'arriver frais.",
                style: TextStyle(color: Colors.orange),
              ),
            TextFormField(
              controller: _target,
              decoration: const InputDecoration(
                labelText: 'Temps visé (optionnel)',
                hintText: '50:00 ou 1:45:00',
                helperText: 'Sert à calculer tes allures d\'entraînement',
              ),
              keyboardType: TextInputType.datetime,
              validator: (v) =>
                  (v ?? '').trim().isEmpty || _parseTime(v!) != null ? null : 'Format : mm:ss ou h:mm:ss',
            ),
            const SizedBox(height: 24),
            Text('Séances par semaine : $_spw'),
            Slider(
              value: _spw.toDouble(),
              min: 2,
              max: 6,
              divisions: 4,
              label: '$_spw',
              onChanged: (v) => setState(() => _spw = v.round()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Créer mon programme'),
            ),
          ],
        ),
      ),
    );
  }
}
