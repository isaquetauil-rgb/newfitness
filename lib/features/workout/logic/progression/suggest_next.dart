/// Sugestão da próxima carga a partir das últimas sessões de um exercício.
/// Lógica pura: sem Flutter e sem Firebase.
library;

import 'package:newfitness/shared/models/workout_set.dart';

import 'progression_rule.dart';

/// Uma sessão passada do exercício: as séries feitas naquele dia.
class ExerciseSession {
  const ExerciseSession({required this.date, required this.sets});

  final DateTime date;
  final List<WorkoutSet> sets;
}

/// O que sugerir para a próxima sessão, com o motivo em pt-BR.
class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.weightKg,
    required this.targetReps,
    required this.reason,
  });

  final double weightKg;
  final int targetReps;
  final String reason;

  @override
  String toString() => '$weightKg kg × $targetReps — $reason';
}

/// Próxima carga e reps para o exercício, ou `null` quando não há o que
/// sugerir: exercício de peso corporal, por tempo ou distância, ou sem
/// nenhuma sessão com série concluída e carga.
///
/// [sessions] pode vir em qualquer ordem; a mais recente é a referência.
/// Só contam séries marcadas como concluídas e com reps.
///
/// Garantia: a carga só sobe quando todas as séries bateram a meta. Se
/// faltou repetição, a carga se mantém (ou cai, no deload).
///
/// Deload: na linear, após `stallLimit` sessões seguidas sem bater as reps
/// na mesma carga; na dupla, após `stallLimit` sessões seguidas na mesma
/// carga em que o total de reps não subiu em relação à sessão anterior
/// (então são precisas `stallLimit + 1` sessões nessa carga).
ProgressionSuggestion? suggestNext(
  ProgressionRule rule,
  List<ExerciseSession> sessions, {
  bool bodyweight = false,
  bool tracksDuration = false,
  bool tracksDistance = false,
}) {
  if (bodyweight || tracksDuration || tracksDistance) return null;

  final history = <_Session>[for (final s in sessions) ?_Session.from(s, rule)]
    ..sort((a, b) => b.date.compareTo(a.date));
  if (history.isEmpty) return null;

  final last = history.first;
  return switch (rule.type) {
    ProgressionType.linear => _linear(rule, last, history),
    ProgressionType.doubleProgression => _double(rule, last, history),
  };
}

ProgressionSuggestion _linear(
  ProgressionRule rule,
  _Session last,
  List<_Session> history,
) {
  final reps = rule.maxReps;
  final weight = last.weightKg;

  if (last.allSetsReached(reps)) {
    final next = _round(weight + rule.incrementKg, rule.roundingStepKg);
    return ProgressionSuggestion(
      weightKg: next,
      targetReps: reps,
      reason:
          'Você fez ${_sets(last.setCount)} de $reps reps com ${_kg(weight)}. '
          'Suba para ${_kg(next)}.',
    );
  }

  // Sessões seguidas, a partir da mais recente, sem bater a meta nesta carga.
  var stalls = 0;
  for (final s in history) {
    if (s.weightKg != weight || s.allSetsReached(reps)) break;
    stalls++;
  }

  if (stalls >= rule.stallLimit) {
    final next = _deload(weight, rule);
    return ProgressionSuggestion(
      weightKg: next,
      targetReps: reps,
      reason:
          'Você não completou as $reps reps com ${_kg(weight)} em $stalls '
          'treinos seguidos. Reduza ${_pct(rule.deloadPercent)} para '
          '${_kg(next)} e suba de novo aos poucos.',
    );
  }

  return ProgressionSuggestion(
    weightKg: weight,
    targetReps: reps,
    reason:
        'Faltaram reps no último treino (${last.repsSummary}). Mantenha '
        '${_kg(weight)} até fazer $reps reps em todas as séries.',
  );
}

ProgressionSuggestion _double(
  ProgressionRule rule,
  _Session last,
  List<_Session> history,
) {
  final weight = last.weightKg;
  final lo = rule.minReps;
  final hi = rule.maxReps;

  if (last.allSetsReached(hi)) {
    final next = _round(weight + rule.incrementKg, rule.roundingStepKg);
    return ProgressionSuggestion(
      weightKg: next,
      targetReps: lo,
      reason:
          'Você chegou a $hi reps em todas as séries com ${_kg(weight)}. '
          'Suba para ${_kg(next)} e volte para $lo reps.',
    );
  }

  // Sessões seguidas, a partir da mais recente, em que o total de reps não
  // subiu em relação à sessão anterior, sempre na mesma carga.
  var stalls = 0;
  for (int i = 0; i + 1 < history.length; i++) {
    final current = history[i];
    final previous = history[i + 1];
    if (current.weightKg != weight || previous.weightKg != weight) break;
    if (current.totalReps > previous.totalReps) break;
    stalls++;
  }

  if (stalls >= rule.stallLimit) {
    final next = _deload(weight, rule);
    return ProgressionSuggestion(
      weightKg: next,
      targetReps: lo,
      reason:
          'Suas reps com ${_kg(weight)} não aumentaram em $stalls treinos '
          'seguidos. Reduza ${_pct(rule.deloadPercent)} para ${_kg(next)}, '
          'volte para $lo reps e suba de novo aos poucos.',
    );
  }

  final target = (last.minRepsDone + 1).clamp(lo, hi);
  return ProgressionSuggestion(
    weightKg: weight,
    targetReps: target,
    reason:
        'Último treino com ${_kg(weight)}: ${last.repsSummary} reps. '
        'Mantenha a carga e tente $target reps em cada série. Quando chegar '
        'a $hi em todas, a carga sobe.',
  );
}

/// Sessão já filtrada: só séries concluídas, com reps e carga.
class _Session {
  _Session(this.date, this.reps, this.weightKg, this.targetSets);

  final DateTime date;
  final List<int> reps;

  /// Carga de trabalho: a maior carga entre as séries concluídas.
  final double weightKg;
  final int? targetSets;

  static _Session? from(ExerciseSession s, ProgressionRule rule) {
    // Aquecimento e drop ficam de fora: o aquecimento é leve de propósito, e
    // o drop vem logo depois de outra série com menos carga e menos reps —
    // contá-los faria a carga nunca subir.
    final done = [
      for (final set in s.sets)
        if (set.completed &&
            set.reps > 0 &&
            set.type != SetType.warmup &&
            set.type != SetType.drop)
          set,
    ];
    if (done.isEmpty) return null;
    final weight = done.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    // Tudo sem carga: peso corporal na prática, não há o que progredir.
    if (weight <= 0) return null;
    return _Session(
      s.date,
      [for (final set in done) set.reps],
      weight,
      rule.targetSets,
    );
  }

  int get setCount => reps.length;
  int get totalReps => reps.fold(0, (a, b) => a + b);
  int get minRepsDone => reps.reduce((a, b) => a < b ? a : b);

  /// Todas as séries com pelo menos [target] reps, e nenhuma série faltando.
  bool allSetsReached(int target) =>
      (targetSets == null || reps.length >= targetSets!) &&
      reps.every((r) => r >= target);

  String get repsSummary => reps.join(', ');
}

double _round(double kg, double step) {
  final rounded = (kg / step).round() * step;
  // Evita 62.50000001 por causa de ponto flutuante.
  return double.parse(rounded.toStringAsFixed(2));
}

double _deload(double weight, ProgressionRule rule) {
  final step = rule.roundingStepKg;
  var next = _round(weight * (1 - rule.deloadPercent / 100), step);
  // Cargas pequenas podem arredondar de volta para o mesmo peso.
  if (next >= weight) next = _round(weight - step, step);
  return next > 0 ? next : weight;
}

String _kg(double kg) {
  final text = kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toStringAsFixed(kg * 10 == (kg * 10).roundToDouble() ? 1 : 2);
  return '${text.replaceAll('.', ',')} kg';
}

String _pct(double p) =>
    '${(p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString()).replaceAll('.', ',')}%';

String _sets(int n) => n == 1 ? '1 série' : '$n séries';
