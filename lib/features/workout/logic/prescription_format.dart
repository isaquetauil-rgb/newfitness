import 'package:newfitness/shared/models/training_plan.dart';

/// Textos da prescrição mostrada durante o treino (ver `WorkoutScreen`).
/// Só APRESENTAM o que o instrutor definiu — nada aqui interpreta,
/// converte em número de execução ou compara com o realizado.

final _numericReps = RegExp(r'^[\d\s\-–]+$');

/// "4 séries × 10 reps", "3 séries × 8–12 reps (cada lado)". Uma faixa
/// ("8-12") é mostrada como faixa; texto livre ("até a falha") como veio.
String prescriptionSetsReps(PlanExercise p, {bool unilateral = false}) {
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
