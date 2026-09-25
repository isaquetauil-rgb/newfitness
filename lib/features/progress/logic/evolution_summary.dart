import 'package:newfitness/shared/models/physical_assessment.dart';

/// Uma linha de comparação "antes → depois" entre duas avaliações. Só
/// apresenta os valores registrados e a diferença — nenhuma interpretação.
class MetricComparison {
  const MetricComparison({
    required this.key,
    required this.label,
    required this.unit,
    this.before,
    this.after,
  });

  final String key;
  final String label;
  final String unit;
  final double? before;
  final double? after;

  /// Nulo quando algum dos lados não foi medido.
  double? get difference =>
      before == null || after == null ? null : after! - before!;
}

/// Cálculos puros sobre o histórico de avaliações (sem Flutter/Firestore),
/// usados pela tela de evolução do aluno e pela visão do instrutor.
class EvolutionSummary {
  EvolutionSummary(List<PhysicalAssessment> assessments, {this.profileHeightCm})
    : chronological = [...assessments]
        ..sort((a, b) => a.date.compareTo(b.date));

  /// Mais antiga primeiro.
  final List<PhysicalAssessment> chronological;

  /// Altura do perfil — usada no IMC quando nenhuma avaliação tem altura.
  final double? profileHeightCm;

  bool get isEmpty => chronological.isEmpty;

  PhysicalAssessment? get first =>
      chronological.isEmpty ? null : chronological.first;
  PhysicalAssessment? get latest =>
      chronological.isEmpty ? null : chronological.last;

  /// Valor mais recente de uma métrica e a avaliação de onde ele veio.
  (double, PhysicalAssessment)? _latestOf(
    double? Function(PhysicalAssessment) pick,
  ) {
    for (final a in chronological.reversed) {
      final v = pick(a);
      if (v != null) return (v, a);
    }
    return null;
  }

  (double, PhysicalAssessment)? _firstOf(
    double? Function(PhysicalAssessment) pick,
  ) {
    for (final a in chronological) {
      final v = pick(a);
      if (v != null) return (v, a);
    }
    return null;
  }

  double? get currentWeightKg => _latestOf((a) => a.weightKg)?.$1;
  DateTime? get currentWeightDate => _latestOf((a) => a.weightKg)?.$2.date;
  double? get initialWeightKg => _firstOf((a) => a.weightKg)?.$1;

  /// Variação entre o primeiro e o último peso registrados (nula com menos
  /// de dois registros de peso).
  double? get weightChangeKg {
    final first = _firstOf((a) => a.weightKg);
    final last = _latestOf((a) => a.weightKg);
    if (first == null || last == null || identical(first.$2, last.$2)) {
      return null;
    }
    return last.$1 - first.$1;
  }

  double? get currentHeightCm =>
      _latestOf((a) => a.heightCm)?.$1 ?? profileHeightCm;

  double? get currentBmi =>
      PhysicalAssessment.calculateBmi(currentWeightKg, currentHeightCm);

  double? get currentBodyFatPercent => _latestOf((a) => a.bodyFatPercent)?.$1;

  double? get currentMuscleMassKg => _latestOf((a) => a.muscleMassKg)?.$1;

  /// Último valor de cada medida registrada ao menos uma vez.
  Map<String, double> get currentMeasurements => {
    for (final key in BodyMeasurement.keysIn(chronological))
      if (_latestOf((a) => a.measurementsCm[key]) case final found?)
        key: found.$1,
  };

  /// Série (data, valor) de uma métrica, só com os pontos registrados.
  List<(DateTime, double)> series(double? Function(PhysicalAssessment) pick) {
    return [
      for (final a in chronological)
        if (pick(a) case final v?) (a.date, v),
    ];
  }

  /// Linhas de comparação entre [before] e [after]: métricas gerais e todas
  /// as medidas registradas em pelo menos uma das duas avaliações.
  List<MetricComparison> compare(
    PhysicalAssessment before,
    PhysicalAssessment after,
  ) {
    final rows = <MetricComparison>[
      MetricComparison(
        key: 'weightKg',
        label: 'Peso',
        unit: 'kg',
        before: before.weightKg,
        after: after.weightKg,
      ),
      MetricComparison(
        key: 'heightCm',
        label: 'Altura',
        unit: 'cm',
        before: before.heightCm,
        after: after.heightCm,
      ),
      MetricComparison(
        key: 'bmi',
        label: 'IMC',
        unit: 'kg/m²',
        before: before.bmi(fallbackHeightCm: profileHeightCm),
        after: after.bmi(fallbackHeightCm: profileHeightCm),
      ),
      MetricComparison(
        key: 'bodyFatPercent',
        label: '% de gordura',
        unit: '%',
        before: before.bodyFatPercent,
        after: after.bodyFatPercent,
      ),
      MetricComparison(
        key: 'muscleMassKg',
        label: 'Massa muscular',
        unit: 'kg',
        before: before.muscleMassKg,
        after: after.muscleMassKg,
      ),
      for (final key in BodyMeasurement.keysIn([before, after]))
        MetricComparison(
          key: key,
          label: BodyMeasurement.labelOf(key),
          unit: 'cm',
          before: before.measurementsCm[key],
          after: after.measurementsCm[key],
        ),
    ];
    return [
      for (final r in rows)
        if (r.before != null || r.after != null) r,
    ];
  }
}

/// Formata um número com até 1 casa decimal, sem ".0" desnecessário e com
/// vírgula (pt-BR): 80 → "80", 80.25 → "80,3".
String formatMetric(double value, {int decimals = 1}) {
  final fixed = value.toStringAsFixed(decimals);
  final trimmed = fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
  return trimmed.replaceAll('.', ',');
}

/// Diferença com sinal explícito: -4 → "-4", 1.5 → "+1,5", 0 → "0".
String formatDifference(double diff, {int decimals = 1}) {
  final rounded = double.parse(diff.toStringAsFixed(decimals));
  if (rounded == 0) return '0';
  final sign = rounded > 0 ? '+' : '-';
  return '$sign${formatMetric(rounded.abs(), decimals: decimals)}';
}
