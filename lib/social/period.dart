enum Period {
  week('Semaine'),
  month('Mois'),
  year('Année');

  final String label;
  const Period(this.label);

  /// Début de la période en cours (lundi, 1er du mois, 1er janvier).
  DateTime start([DateTime? now]) {
    final n = now ?? DateTime.now();
    return switch (this) {
      Period.week => DateTime(n.year, n.month, n.day - (n.weekday - 1)),
      Period.month => DateTime(n.year, n.month),
      Period.year => DateTime(n.year),
    };
  }
}
