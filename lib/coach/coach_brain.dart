import 'dart:math';

import '../models/run.dart';
import '../records/best_efforts.dart';
import '../services/geo.dart';
import '../shoes/shoes.dart';
import '../training/models.dart';
import '../weather/weather.dart';

/// Tout ce que l'assistante sait, rassemblé sur le téléphone (rien n'est envoyé).
class CoachSnapshot {
  final DateTime now;
  final String name;
  final List<Run> runs; // plus récentes d'abord
  final List<PersonalRecord> records;
  final List<PlannedSession> upcoming;
  final RaceGoal? nextRace;
  final List<Shoe> shoes;
  final double? kcalLeftToday;
  final Weather? weather;

  const CoachSnapshot({
    required this.now,
    this.name = '',
    this.runs = const [],
    this.records = const [],
    this.upcoming = const [],
    this.nextRace,
    this.shoes = const [],
    this.kcalLeftToday,
    this.weather,
  });

  DateTime get today => DateTime(now.year, now.month, now.day);

  double kmBetween(DateTime from, DateTime to) => runs
      .where((r) => !r.startedAt.isBefore(from) && r.startedAt.isBefore(to))
      .fold(0.0, (s, r) => s + r.distanceM / 1000);

  int countBetween(DateTime from, DateTime to) =>
      runs.where((r) => !r.startedAt.isBefore(from) && r.startedAt.isBefore(to)).length;

  /// Charge des 7 derniers jours / moyenne hebdo des 4 dernières semaines
  /// (ratio aigu/chronique). Au-delà de 1,3 le risque de blessure augmente.
  double? get loadRatio {
    final end = today.add(const Duration(days: 1));
    final acute = kmBetween(end.subtract(const Duration(days: 7)), end);
    final chronic = kmBetween(end.subtract(const Duration(days: 28)), end) / 4;
    if (chronic < 5) return null; // pas assez d'historique
    return acute / chronic;
  }

  int? get daysSinceLastRun => runs.isEmpty
      ? null
      : today.difference(DateTime(runs.first.startedAt.year, runs.first.startedAt.month, runs.first.startedAt.day)).inDays;
}

/// Assistante de course locale : répond en français à partir des données du téléphone.
class CoachBrain {
  final CoachSnapshot s;
  final Random _rnd;
  CoachBrain(this.s, {Random? random}) : _rnd = random ?? Random();

  String _km(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Message d'accueil avec les points importants du moment.
  String greeting() {
    final hello = s.now.hour < 12 ? 'Bonjour' : (s.now.hour < 18 ? 'Salut' : 'Bonsoir');
    final lines = <String>['$hello${s.name.isEmpty ? '' : ' ${s.name}'} ! 👋', ...insights()];
    if (lines.length == 1) lines.add('Pose-moi une question : ta semaine, ta prochaine séance, tes records, quoi manger…');
    return lines.join('\n\n');
  }

  /// Points d'attention, du plus important au moins important.
  List<String> insights() {
    final out = <String>[];
    final ratio = s.loadRatio;
    if (ratio != null && ratio > 1.5) {
      out.add('⚠️ Tu as couru ${((ratio - 1) * 100).round()} % de plus que d\'habitude cette semaine. '
          'Risque de blessure : prévois une journée de repos ou un footing très lent.');
    } else if (ratio != null && ratio > 1.3) {
      out.add('📈 Ta charge augmente vite (+${((ratio - 1) * 100).round()} %). Garde les prochains footings bien tranquilles.');
    }
    final today = s.upcoming.where((x) => _sameDay(x.date, s.today)).firstOrNull;
    if (today != null) out.add('📅 Au programme aujourd\'hui : ${today.description}');
    final race = s.nextRace;
    if (race != null) {
      final d = DateTime(race.date.year, race.date.month, race.date.day).difference(s.today).inDays;
      if (d >= 0 && d <= 7) out.add('🏅 ${race.name} dans $d jour${d > 1 ? 's' : ''}. On lève le pied et on soigne le sommeil et l\'alimentation.');
    }
    final since = s.daysSinceLastRun;
    if (since != null && since >= 5 && today == null) {
      out.add('🛋️ Pas de course depuis $since jours. Une petite sortie de 20-30 min pour relancer la machine ?');
    }
    for (final shoe in s.shoes.where((x) => !x.retired)) {
      final w = shoe.wearWarning;
      if (w != null) out.add('👟 ${shoe.name} : $w');
    }
    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Réponse à une question libre.
  String answer(String question) {
    final q = question
        .toLowerCase()
        .replaceAll(RegExp('[éèê]'), 'e')
        .replaceAll(RegExp('[àâ]'), 'a')
        .replaceAll(RegExp('[ùû]'), 'u')
        .replaceAll('ç', 'c');
    bool has(List<String> w) => w.any(q.contains);

    if (has(['manger', 'nutrition', 'calorie', 'kcal', 'repas', 'faim', 'grignot'])) return _food();
    if (has(['record', 'meilleur', 'pb', 'perf'])) return _records();
    if (has(['seance', 'programme', 'plan', 'entrainement', 'demain', 'aujourd'])) return _nextSession();
    if (has(['semaine', 'bilan', 'resume', 'mois', 'combien'])) return _week();
    if (has(['allure', 'vitesse', 'progres', 'progresse', 'rapide', 'lent'])) return _progress();
    if (has(['fatigue', 'repos', 'blessure', 'douleur', 'mal', 'recup', 'surentrainement'])) return _recovery();
    if (has(['chaussure', 'basket', 'usure'])) return _shoes();
    if (has(['meteo', 'pluie', 'froid', 'chaud', 'tenue', 'habiller', 'sortir'])) return _weather();
    if (has(['course', 'epreuve', 'marathon', 'semi', 'objectif', 'competition'])) return _race();
    if (has(['motiv', 'envie', 'flemme', 'courage', 'dur'])) return _motivation();
    if (has(['bonjour', 'salut', 'hello', 'coucou'])) return greeting();
    return 'Je peux te parler de ta semaine, de ta progression, de ta prochaine séance, de tes records, '
        'de ta récupération, de ton alimentation du jour, de tes chaussures ou de la météo. Essaie « bilan de la semaine » !';
  }

  String _week() {
    final monday = s.today.subtract(Duration(days: s.today.weekday - 1));
    final next = monday.add(const Duration(days: 7));
    final prev = monday.subtract(const Duration(days: 7));
    final km = s.kmBetween(monday, next), n = s.countBetween(monday, next);
    final kmPrev = s.kmBetween(prev, monday);
    final month = s.kmBetween(DateTime(s.now.year, s.now.month), next);
    if (n == 0) {
      return 'Pas encore de course cette semaine (${_km(kmPrev)} km la semaine dernière). '
          '${s.upcoming.isNotEmpty ? 'Prochaine séance : ${s.upcoming.first.description}' : 'Une sortie tranquille pour commencer ?'}';
    }
    final diff = kmPrev == 0 ? '' : ' (${km >= kmPrev ? '+' : ''}${((km - kmPrev) / kmPrev * 100).round()} % vs semaine dernière)';
    return 'Cette semaine : $n course${n > 1 ? 's' : ''}, ${_km(km)} km$diff. Ce mois-ci : ${_km(month)} km.';
  }

  String _progress() {
    final valid = s.runs.where((r) => r.distanceM >= 2000).toList();
    if (valid.length < 4) return 'Il me faut au moins 4 courses de plus de 2 km pour mesurer ta progression. Continue !';
    final n = min(5, valid.length ~/ 2);
    double avg(Iterable<Run> rs) => rs.fold(0.0, (a, r) => a + r.distanceM) / rs.fold(0.0, (a, r) => a + r.movingTime.inSeconds);
    final recent = avg(valid.take(n)), before = avg(valid.skip(n).take(n));
    final gain = (1000 / before - 1000 / recent).round(); // secondes gagnées par km
    final trend = gain > 3
        ? 'Tu gagnes environ $gain s/km, belle progression ! 🚀'
        : gain < -3
            ? 'Tu es un peu plus lent (${-gain} s/km) : fatigue, chaleur ou sorties plus longues ? C\'est normal par périodes.'
            : 'Allure stable : c\'est le bon moment pour ajouter une séance de fractionné.';
    return 'Allure moyenne sur tes $n dernières courses : ${formatPace(recent)}/km (avant : ${formatPace(before)}/km). $trend';
  }

  String _records() {
    if (s.records.isEmpty) return 'Pas encore de record : chaque course compte, le premier arrive vite !';
    return 'Tes records :\n${s.records.take(6).map((r) => '• ${r.label} : ${r.value}').join('\n')}';
  }

  String _nextSession() {
    if (s.upcoming.isEmpty) {
      return 'Pas de programme en cours. Crée un objectif dans l\'onglet Entraînement et je te prépare des séances.';
    }
    final x = s.upcoming.first;
    final when = _sameDay(x.date, s.today)
        ? 'aujourd\'hui'
        : _sameDay(x.date, s.today.add(const Duration(days: 1)))
            ? 'demain'
            : 'le ${x.date.day}/${x.date.month}';
    return 'Prochaine séance $when — ${x.type.label} : ${x.description}';
  }

  String _recovery() {
    final ratio = s.loadRatio;
    final since = s.daysSinceLastRun;
    final base = ratio == null
        ? 'Je n\'ai pas encore assez d\'historique pour mesurer ta charge.'
        : ratio > 1.3
            ? 'Ta charge des 7 derniers jours est élevée (×${ratio.toStringAsFixed(1).replaceAll('.', ',')} par rapport à ta moyenne). Repos ou footing très lent conseillé.'
            : 'Ta charge est raisonnable (×${ratio.toStringAsFixed(1).replaceAll('.', ',')} par rapport à ta moyenne).';
    return '$base${since == 0 ? ' Tu as couru aujourd\'hui : étirements doux, hydratation et un repas avec glucides + protéines.' : ''}'
        ' Si une douleur dure plus de 3 jours ou augmente en courant, arrête et consulte.';
  }

  String _food() {
    final left = s.kcalLeftToday;
    if (left == null) return 'Ouvre l\'onglet Nutrition pour que je calcule ton objectif du jour.';
    if (left > 600) return 'Il te reste environ ${left.round()} kcal aujourd\'hui. Un vrai repas avec féculents, protéines et légumes serait parfait.';
    if (left > 150) return 'Il te reste environ ${left.round()} kcal : une collation (skyr, fruit, tartine) suffit.';
    if (left >= -150) return 'Tu es pile dans ton objectif du jour 👌';
    return 'Tu as dépassé ton objectif d\'environ ${(-left).round()} kcal. Pas de panique : un écart ponctuel ne compte pas, c\'est la régularité qui fait la différence.';
  }

  String _shoes() {
    final active = s.shoes.where((x) => !x.retired).toList();
    if (active.isEmpty) return 'Ajoute tes chaussures (menu ⋮ > Chaussures) et je surveille leur usure.';
    return active.map((x) => '👟 ${x.name} : ${x.km.round()} / ${x.maxKm.round()} km${x.wearWarning == null ? ' ✓' : ' — ${x.wearWarning}'}').join('\n');
  }

  String _weather() {
    final w = s.weather;
    if (w == null) return 'Je n\'ai pas la météo pour l\'instant (localisation ou réseau indisponible).';
    return '${w.description}, ${w.temp.round()}° (ressenti ${w.feelsLike.round()}°).\n${outfitAdvice(w).map((t) => '• $t').join('\n')}';
  }

  String _race() {
    final r = s.nextRace;
    if (r == null) return 'Pas d\'épreuve prévue. Ajoute un objectif dans l\'onglet Entraînement !';
    final d = DateTime(r.date.year, r.date.month, r.date.day).difference(s.today).inDays;
    final pace = r.racePaceSecPerKm;
    return '${r.name} (${_km(r.distanceKm)} km) dans $d jours.'
        '${pace == null ? '' : ' Allure visée : ${formatPace(1000 / pace)}/km.'}'
        ' ${s.upcoming.where((x) => x.goalId == r.id).length} séances restantes au programme.';
  }

  static const _quotes = [
    'La séance la plus dure, c\'est celle où on enfile les baskets. Après, ça roule. 💪',
    'Pas besoin d\'aller vite : il faut juste y aller.',
    'Chaque kilomètre de plus est un kilomètre que tu n\'avais pas hier.',
    'Tu ne regretteras jamais une sortie. Tu regretteras celle que tu n\'as pas faite.',
    'Dix minutes valent mieux que zéro. Lance-toi, tu décideras après.',
  ];

  String _motivation() {
    final week = s.kmBetween(s.today.subtract(Duration(days: s.today.weekday - 1)), s.today.add(const Duration(days: 1)));
    final q = _quotes[_rnd.nextInt(_quotes.length)];
    return week > 0 ? '$q Déjà ${_km(week)} km cette semaine, continue !' : q;
  }
}
