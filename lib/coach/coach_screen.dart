import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/user_profile.dart';
import '../nutrition/models.dart';
import '../nutrition/nutrition_calc.dart';
import '../nutrition/nutrition_repository.dart';
import '../records/records_repository.dart';
import '../services/run_repository.dart';
import '../services/voice_coach.dart';
import '../shoes/shoes.dart';
import '../training/plan_repository.dart';
import '../weather/weather.dart';
import 'coach_brain.dart';

/// Assistante locale : tout est calculé sur le téléphone, rien n'est envoyé.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _Msg {
  final String text;
  final bool fromMe;
  const _Msg(this.text, this.fromMe);
}

class _CoachScreenState extends State<CoachScreen> {
  CoachBrain? _brain;
  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _speak = false;

  static const _suggestions = [
    'Bilan de la semaine',
    'Est-ce que je progresse ?',
    'Ma prochaine séance',
    'Je suis fatigué',
    'Mes records',
    'Il me reste combien de calories ?',
    'Quelle tenue aujourd\'hui ?',
    'Motive-moi',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final runsRepo = context.read<RunRepository>();
    final plans = context.read<PlanRepository>();
    final records = context.read<RecordsRepository>();
    final shoes = context.read<ShoeRepository>();
    final nutrition = context.read<NutritionRepository>();
    final profile = context.read<ProfileState>().profile ?? const UserProfile();

    final now = DateTime.now();
    final goals = await plans.goals();
    final today = FoodEntry.dayOf(now);
    final settings = await nutrition.settings();
    final (runKcal, _) = await nutrition.runsOf(today);
    final eaten = (await nutrition.entries(today)).fold<double>(0, (s, e) => s + e.kcal);
    Weather? weather;
    try {
      weather = await Weather.here();
    } catch (_) {}

    final snapshot = CoachSnapshot(
      now: now,
      name: profile.name,
      runs: await runsRepo.list(),
      records: await records.all(),
      upcoming: await plans.upcomingSessions(days: 60),
      nextRace: goals.where((g) => !FoodEntry.dayOf(g.date).isBefore(today)).firstOrNull,
      shoes: await shoes.list(),
      kcalLeftToday: NutritionCalc.dailyTarget(profile, settings.activity, settings.goal, runKcal: runKcal) - eaten,
      weather: weather,
    );
    if (!mounted) return;
    setState(() {
      _brain = CoachBrain(snapshot);
      _msgs.add(_Msg(_brain!.greeting(), false));
    });
  }

  void _ask(String q) {
    final brain = _brain;
    if (brain == null || q.trim().isEmpty) return;
    final a = brain.answer(q);
    setState(() {
      _msgs
        ..add(_Msg(q.trim(), true))
        ..add(_Msg(a, false));
    });
    _input.clear();
    if (_speak) context.read<VoiceCoach>().say(a.replaceAll(RegExp(r'[•\n]'), ' '));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistante'),
        actions: [
          IconButton(
            tooltip: _speak ? 'Réponses lues à voix haute' : 'Lire les réponses à voix haute',
            isSelected: _speak,
            icon: const Icon(Icons.volume_off),
            selectedIcon: const Icon(Icons.volume_up),
            onPressed: () => setState(() => _speak = !_speak),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _brain == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                  for (final m in _msgs)
                    Align(
                      alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m.fromMe ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(m.text),
                      ),
                    ),
                ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            for (final s in _suggestions)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ActionChip(label: Text(s), onPressed: () => _ask(s))),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: const InputDecoration(hintText: 'Pose ta question…'),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: () => _ask(_input.text)),
            ]),
          ),
        ),
      ]),
    );
  }
}
