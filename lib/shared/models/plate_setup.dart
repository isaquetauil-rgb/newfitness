/// Barra e anilhas que a academia do aluno tem — guardado no perfil
/// (`users/{uid}.plateSetup`, campo opcional) para a calculadora de anilhas.
class PlateSetup {
  const PlateSetup({
    this.barKg = defaultBarKg,
    this.platesKg = defaultPlatesKg,
  });

  static const double defaultBarKg = 20;

  /// Tamanhos de anilha comuns no Brasil, do maior para o menor.
  static const List<double> defaultPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25];

  /// Todos os tamanhos que o aluno pode marcar na configuração.
  static const List<double> allPlatesKg = [
    25,
    20,
    15,
    10,
    5,
    2.5,
    2,
    1.25,
    1,
    0.5,
  ];

  /// Barras comuns: olímpica (20), feminina (15), curta ou W (10).
  static const List<double> commonBarsKg = [20, 15, 10, 8, 7];

  final double barKg;

  /// Tamanhos disponíveis (o aluno tem pares de cada um).
  final List<double> platesKg;

  factory PlateSetup.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlateSetup();
    final bar = (map['barKg'] as num?)?.toDouble();
    final plates = [
      for (final p in (map['platesKg'] as List<dynamic>? ?? const []))
        if (p is num && p > 0 && p <= 50) p.toDouble(),
    ]..sort((a, b) => b.compareTo(a));
    return PlateSetup(
      barKg: bar != null && bar >= 0 && bar <= 50 ? bar : defaultBarKg,
      platesKg: plates.isEmpty ? defaultPlatesKg : plates,
    );
  }

  Map<String, dynamic> toMap() => {'barKg': barKg, 'platesKg': platesKg};

  PlateSetup copyWith({double? barKg, List<double>? platesKg}) => PlateSetup(
    barKg: barKg ?? this.barKg,
    platesKg: platesKg ?? this.platesKg,
  );
}
