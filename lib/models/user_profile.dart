enum Sex { male, female, other }

/// Données physiques de l'utilisateur, utilisées pour les calculs (calories, foulée...).
class UserProfile {
  final String name;
  final double weightKg;
  final double heightCm;
  final Sex sex;
  final DateTime? birthDate;
  final int? maxHeartRate;

  const UserProfile({
    this.name = '',
    this.weightKg = 70,
    this.heightCm = 175,
    this.sex = Sex.other,
    this.birthDate,
    this.maxHeartRate,
  });

  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a;
  }

  /// Fréquence cardiaque max estimée (Tanaka) si non renseignée.
  int? get estimatedMaxHeartRate =>
      maxHeartRate ?? (age == null ? null : (208 - 0.7 * age!).round());

  /// Longueur de foulée estimée en course (m), utile si le GPS décroche.
  double get estimatedStrideM {
    final factor = switch (sex) { Sex.male => 0.415, Sex.female => 0.413, Sex.other => 0.414 };
    // En course la foulée est environ 1,6 fois la foulée de marche.
    return heightCm / 100 * factor * 1.6;
  }

  /// Indice de masse corporelle.
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  UserProfile copyWith({
    String? name,
    double? weightKg,
    double? heightCm,
    Sex? sex,
    DateTime? birthDate,
    int? maxHeartRate,
  }) =>
      UserProfile(
        name: name ?? this.name,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        sex: sex ?? this.sex,
        birthDate: birthDate ?? this.birthDate,
        maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sex': sex.name,
        'birthDate': birthDate?.toIso8601String(),
        'maxHeartRate': maxHeartRate,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String? ?? '',
        weightKg: (j['weightKg'] as num?)?.toDouble() ?? 70,
        heightCm: (j['heightCm'] as num?)?.toDouble() ?? 175,
        sex: Sex.values.firstWhere((s) => s.name == j['sex'], orElse: () => Sex.other),
        birthDate: j['birthDate'] == null ? null : DateTime.tryParse(j['birthDate'] as String),
        maxHeartRate: j['maxHeartRate'] as int?,
      );
}
