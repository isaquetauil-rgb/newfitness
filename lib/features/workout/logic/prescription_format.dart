import 'package:newfitness/shared/models/training_plan.dart';

/// Textos da prescrição mostrada durante o treino (ver `WorkoutScreen`).
/// Só APRESENTAM o que o instrutor definiu — nada aqui interpreta,
/// converte em número de execução ou compara com o realizado.

final _numericReps = RegExp(r'^[\d\s\-–]+$');

/// "4 séries × 10 reps", "3 séries × 8–12 reps (cada lado)". Uma faixa
/// ("8-12") é mostrada como faixa; texto livre ("até a falha") como veio.
String prescriptionSetsReps(PlanExercise p, {bool unilateral = false}) {
  // Exercício "em aberto": o personal não definiu séries; o aluno decide no
  // treino.
  if (p.targetSets <= 0) {
    return 'Séries em aberto${unilateral ? ' (cada lado)' : ''}';
  }
  final sets = '${p.targetSets} ${p.targetSets == 1 ? 'série' : 'séries'}';
  final raw = p.targetReps.trim();
  final reps = raw.isEmpty
      ? ''
      : _numericReps.hasMatch(raw)
      ? ' × ${raw.replaceAll('-', '–').replaceAll(RegExp(r'\s+'), '')} reps'
      : ' × $raw';
  return '$sets$reps${unilateral ? ' (cada lado)' : ''}';
}

/// Carga exatamente como prescrita ("30 kg", "40/50/60 kg"); `null` sem
/// carga. Não vira número — é só o texto do instrutor.
String? prescriptionLoad(PlanExercise p) {
  final raw = p.targetWeightsKg.trim();
  if (raw.isEmpty) return null;
  return raw.toLowerCase().contains('kg') ? raw : '$raw kg';
}

/// "Descanso: 90 s".
String prescriptionRest(PlanExercise p) => 'Descanso: ${p.restSeconds} s';

/// Uma linha do plano na lista de treinos: "Supino — 3x10 · 25 kg · 90 s de
/// descanso"; exercício em aberto: "Agachamento — séries em aberto · 90 s
/// de descanso"; sem descanso (ex.: corrida), sem a parte do descanso.
String prescriptionSummaryLine(PlanExercise p) {
  final sets = p.targetSets <= 0
      ? 'séries em aberto'
      : '${p.targetSets}x${p.targetReps}';
  final load = p.targetWeightsKg.trim().isEmpty
      ? ''
      : ' · ${prescriptionLoad(p)}';
  final rest = p.restSeconds > 0 ? ' · ${p.restSeconds}s descanso' : '';
  return '${p.exerciseName} — $sets$load$rest';
}
