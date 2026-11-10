import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'shoes.dart';

class ShoesScreen extends StatefulWidget {
  const ShoesScreen({super.key});

  @override
  State<ShoesScreen> createState() => _ShoesScreenState();
}

class _ShoesScreenState extends State<ShoesScreen> {
  late Future<(List<Shoe>, int?)> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<ShoeRepository>();
    setState(() => _data = (() async => (await repo.list(), await repo.defaultShoeId()))());
  }

  Future<void> _edit([Shoe? shoe]) async {
    final repo = context.read<ShoeRepository>();
    final name = TextEditingController(text: shoe?.name ?? '');
    final max = TextEditingController(text: (shoe?.maxKm ?? 700).round().toString());
    final start = TextEditingController(text: (shoe?.startKm ?? 0).round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(shoe == null ? 'Nouvelle paire' : 'Modifier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom (ex. Pegasus 41)')),
          TextField(
            controller: max,
            decoration: const InputDecoration(labelText: 'Durée de vie', suffixText: 'km'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: start,
            decoration: const InputDecoration(labelText: 'Déjà parcourus', suffixText: 'km'),
            keyboardType: TextInputType.number,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final id = await repo.save(Shoe(
      id: shoe?.id,
      name: name.text.trim(),
      maxKm: double.tryParse(max.text) ?? 700,
      startKm: double.tryParse(start.text) ?? 0,
      retired: shoe?.retired ?? false,
      createdAt: shoe?.createdAt ?? DateTime.now(),
    ));
    // La première paire devient la paire par défaut.
    if (await repo.defaultShoeId() == null) await repo.setDefault(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ShoeRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mes chaussures')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une paire'),
        onPressed: _edit,
      ),
      body: FutureBuilder<(List<Shoe>, int?)>(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (shoes, def) = snap.data!;
          if (shoes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Ajoute tes chaussures : les kilomètres de chaque course y seront comptés, '
                    'et je te préviens quand il est temps de les changer.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            for (final s in shoes)
              Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.directions_run, color: s.retired ? Colors.grey : null),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${s.name}${s.retired ? ' (retraitées)' : ''}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (s.id == def) const Chip(label: Text('Par défaut')),
                      PopupMenuButton<String>(
                        itemBuilder: (_) => [
                          if (!s.retired && s.id != def) const PopupMenuItem(value: 'default', child: Text('Paire par défaut')),
                          const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                          PopupMenuItem(value: 'retire', child: Text(s.retired ? 'Réactiver' : 'Mettre à la retraite')),
                          const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                        ],
                        onSelected: (v) async {
                          switch (v) {
                            case 'default':
                              await repo.setDefault(s.id);
                            case 'edit':
                              await _edit(s);
                            case 'retire':
                              await repo.save(Shoe(
                                  id: s.id, name: s.name, maxKm: s.maxKm, startKm: s.startKm,
                                  retired: !s.retired, createdAt: s.createdAt));
                              if (!s.retired && s.id == def) await repo.setDefault(null);
                            case 'delete':
                              await repo.delete(s.id!);
                              if (s.id == def) await repo.setDefault(null);
                          }
                          _reload();
                        },
                      ),
                    ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: s.wear.clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: s.wear >= 1 ? Colors.red : (s.wear >= 0.85 ? Colors.orange : Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Text('${s.km.round()} / ${s.maxKm.round()} km'),
                    if (s.wearWarning != null && !s.retired)
                      Text(s.wearWarning!, style: TextStyle(color: s.wear >= 1 ? Colors.red : Colors.orange)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
