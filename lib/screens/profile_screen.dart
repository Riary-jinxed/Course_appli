import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/user_profile.dart';
import '../services/profile_repository.dart';
import '../services/voice_coach.dart';

class ProfileScreen extends StatefulWidget {
  final bool firstLaunch;
  const ProfileScreen({super.key, this.firstLaunch = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _weight, _height, _hr;
  late Sex _sex;
  DateTime? _birth;
  late AnnounceMode _mode;
  late double _interval;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileState>().profile ?? const UserProfile();
    _name = TextEditingController(text: p.name);
    _weight = TextEditingController(text: widget.firstLaunch ? '' : _num(p.weightKg));
    _height = TextEditingController(text: widget.firstLaunch ? '' : _num(p.heightCm));
    _hr = TextEditingController(text: p.maxHeartRate?.toString() ?? '');
    _sex = p.sex;
    _birth = p.birthDate;
    final coach = context.read<VoiceCoach>();
    _mode = coach.mode;
    _interval = coach.interval;
  }

  String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double? _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  String? _range(String? v, double min, double max) {
    final d = _parse(v ?? '');
    if (d == null) return 'Obligatoire';
    if (d < min || d > max) return 'Entre ${min.toInt()} et ${max.toInt()}';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final profile = UserProfile(
      name: _name.text.trim(),
      weightKg: _parse(_weight.text)!,
      heightCm: _parse(_height.text)!,
      sex: _sex,
      birthDate: _birth,
      maxHeartRate: int.tryParse(_hr.text.trim()),
    );
    final coach = context.read<VoiceCoach>()
      ..mode = _mode
      ..interval = _interval;
    await context.read<ProfileRepository>().saveCoachSettings(coach.mode, coach.interval);
    if (!mounted) return;
    await context.read<ProfileState>().update(profile);
    if (mounted && !widget.firstLaunch) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final unit = _mode == AnnounceMode.time ? 'min' : 'km';
    return Scaffold(
      appBar: AppBar(title: Text(widget.firstLaunch ? 'Bienvenue !' : 'Mon profil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.firstLaunch)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Ces infos servent à calculer tes calories et ta foulée. '
                    'Elles restent sur ton téléphone.'),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Prénom'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _weight,
                  decoration: const InputDecoration(labelText: 'Poids', suffixText: 'kg'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _range(v, 25, 250),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _height,
                  decoration: const InputDecoration(labelText: 'Taille', suffixText: 'cm'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _range(v, 100, 230),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('Sexe'),
            const SizedBox(height: 8),
            SegmentedButton<Sex>(
              segments: const [
                ButtonSegment(value: Sex.female, label: Text('Femme')),
                ButtonSegment(value: Sex.male, label: Text('Homme')),
                ButtonSegment(value: Sex.other, label: Text('Autre')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date de naissance'),
              subtitle: Text(_birth == null ? 'Non renseignée' : DateFormat.yMMMMd('fr_FR').format(_birth!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _birth ?? DateTime(1995),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  locale: const Locale('fr', 'FR'),
                );
                if (d != null) setState(() => _birth = d);
              },
            ),
            TextFormField(
              controller: _hr,
              decoration: const InputDecoration(
                labelText: 'Fréquence cardiaque max (optionnel)',
                suffixText: 'bpm',
              ),
              keyboardType: TextInputType.number,
            ),
            const Divider(height: 40),
            Text('Annonces vocales', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AnnounceMode>(
              segments: const [
                ButtonSegment(value: AnnounceMode.off, label: Text('Aucune')),
                ButtonSegment(value: AnnounceMode.distance, label: Text('Distance')),
                ButtonSegment(value: AnnounceMode.time, label: Text('Temps')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _interval = _mode == AnnounceMode.time ? 5 : 1;
              }),
            ),
            if (_mode != AnnounceMode.off) ...[
              const SizedBox(height: 8),
              Text('Toutes les ${_num(_interval)} $unit'),
              Slider(
                value: _interval,
                min: _mode == AnnounceMode.time ? 1 : 0.5,
                max: _mode == AnnounceMode.time ? 30 : 5,
                divisions: _mode == AnnounceMode.time ? 29 : 9,
                label: '${_num(_interval)} $unit',
                onChanged: (v) => setState(() => _interval = v),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
