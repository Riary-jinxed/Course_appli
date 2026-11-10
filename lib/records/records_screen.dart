import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../screens/run_detail_screen.dart';
import 'best_efforts.dart';
import 'records_repository.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes records')),
      body: FutureBuilder<List<PersonalRecord>>(
        future: context.read<RecordsRepository>().all(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Cours un peu, tes records apparaîtront ici !'));
          return ListView(children: [
            for (final r in list)
              ListTile(
                leading: const Text('🏆', style: TextStyle(fontSize: 24)),
                title: Text(r.label),
                subtitle: r.date == null
                    ? null
                    : Text(r.label == 'Plus grosse semaine'
                        ? 'Semaine du ${DateFormat.yMMMMd('fr_FR').format(r.date!)}'
                        : DateFormat.yMMMMd('fr_FR').format(r.date!)),
                trailing: Text(r.value, style: Theme.of(context).textTheme.titleSmall),
                onTap: r.runId == null
                    ? null
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RunDetailScreen(runId: r.runId!))),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Les temps sur 1 km, 5 km… sont tes portions les plus rapides, '
                  'mesurées n\'importe où pendant une course.', style: TextStyle(fontSize: 12)),
            ),
          ]);
        },
      ),
    );
  }
}
