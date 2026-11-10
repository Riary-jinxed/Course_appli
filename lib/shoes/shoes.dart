import 'package:shared_preferences/shared_preferences.dart';

import '../services/run_repository.dart';

class Shoe {
  final int? id;
  final String name;

  /// Kilométrage conseillé avant remplacement (souvent 600 à 800 km).
  final double maxKm;

  /// Kilomètres déjà faits avant d'être ajoutées dans l'appli.
  final double startKm;
  final bool retired;
  final DateTime createdAt;

  /// Calculé : startKm + courses associées.
  final double km;

  const Shoe({
    this.id,
    required this.name,
    this.maxKm = 700,
    this.startKm = 0,
    this.retired = false,
    required this.createdAt,
    this.km = 0,
  });

  double get wear => maxKm <= 0 ? 0 : km / maxKm;

  /// Message d'usure, ou null si tout va bien.
  String? get wearWarning {
    if (wear >= 1) return 'Usées : ${km.round()} km. Pense à les remplacer pour éviter les blessures.';
    if (wear >= 0.85) return 'Bientôt en fin de vie : ${km.round()} / ${maxKm.round()} km.';
    return null;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'max_km': maxKm,
        'start_km': startKm,
        'retired': retired ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Shoe.fromMap(Map<String, dynamic> m) => Shoe(
        id: m['id'] as int?,
        name: m['name'] as String,
        maxKm: (m['max_km'] as num).toDouble(),
        startKm: (m['start_km'] as num).toDouble(),
        retired: (m['retired'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        km: ((m['km'] as num?) ?? 0).toDouble(),
      );
}

class ShoeRepository {
  final RunRepository runs;
  ShoeRepository(this.runs);

  Future<List<Shoe>> list({bool includeRetired = true}) async {
    final db = await runs.database;
    final rows = await db.rawQuery('''
      SELECT s.*, s.start_km + COALESCE(SUM(r.distance_m), 0) / 1000.0 AS km
      FROM shoes s LEFT JOIN runs r ON r.shoe_id = s.id
      ${includeRetired ? '' : 'WHERE s.retired = 0'}
      GROUP BY s.id ORDER BY s.retired, s.created_at DESC''');
    return rows.map(Shoe.fromMap).toList();
  }

  Future<Shoe?> get(int id) async => (await list()).where((s) => s.id == id).firstOrNull;

  Future<int> save(Shoe s) async {
    final db = await runs.database;
    if (s.id == null) return db.insert('shoes', s.toMap());
    await db.update('shoes', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    return s.id!;
  }

  Future<void> delete(int id) async => (await runs.database).delete('shoes', where: 'id = ?', whereArgs: [id]);

  Future<void> assign(int runId, int? shoeId) async =>
      (await runs.database).update('runs', {'shoe_id': shoeId}, where: 'id = ?', whereArgs: [runId]);

  Future<int?> defaultShoeId() async => (await SharedPreferences.getInstance()).getInt('default_shoe');

  Future<void> setDefault(int? id) async {
    final p = await SharedPreferences.getInstance();
    id == null ? await p.remove('default_shoe') : await p.setInt('default_shoe', id);
  }

  /// Associe la paire par défaut à une nouvelle course. Renvoie la paire (mise à jour).
  Future<Shoe?> assignDefault(int runId) async {
    final id = await defaultShoeId();
    if (id == null) return null;
    final shoe = await get(id);
    if (shoe == null || shoe.retired) return null;
    await assign(runId, id);
    return get(id);
  }
}
