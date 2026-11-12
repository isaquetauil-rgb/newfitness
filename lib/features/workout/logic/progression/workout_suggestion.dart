/// Liga os modelos do app (plano, treino, exercício) à sugestão de carga.
/// Lógica pura: sem Flutter e sem Firebase.
library;

import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';

import 'progression_rule.dart';
import 'suggest_next.dart';

/// Regra usada quando o exercício não vem de um plano: dupla progressão
/// de 8 a 12 reps.
final ProgressionRule defaultFreeWorkoutRule = ProgressionRule.fromTargetReps(
  '8-12',
)!;

/// Quantas sessões passadas entram no cálculo (o deload olha só as últimas).
const int suggestionHistoryLimit = 12;

/// Regra do exercício do plano: o tipo e o incremento escolhidos pelo
/// personal, se houver; senão, deduzidos do texto de reps. `null` quando as
/// reps não são uma contagem ("30 s", "até a falha").
ProgressionRule? ruleForPrescription(PlanExercise p) =>
    ProgressionRule.fromTargetReps(
      p.targetReps,
      type: progressionTypeFromString(p.progressionType),
      targetSets: p.targetSets,
      incrementKg:
          p.progressionIncrementKg ?? ProgressionRule.defaultIncrementKg,
    );

/// Sessões passadas de [exerciseId] em [history] (treinos já salvos).
List<ExerciseSession> sessionsFor(String exerciseId, List<Workout> history) {
  final sessions = <ExerciseSession>[
    for (final workout in history)
      for (final logged in workout.exercises)
        if (logged.exerciseId == exerciseId)
          ExerciseSession(date: workout.date, sets: logged.sets),
  ]..sort((a, b) => b.date.compareTo(a.date));
  return sessions.take(suggestionHistoryLimit).toList();
}

/// Exercício medido em tempo: marcado no cadastro (`tracksDuration`) ou com
/// a prescrição em segundos/minutos ("20-30 s"). A coluna "Reps" vira
/// "Seg" e o número é a duração.
bool isTimedExercise(LoggedExercise exercise, {Exercise? library}) {
  if (library?.tracksDuration ?? false) return true;
  final p = exercise.prescription;
  return p != null && repsTextIsTimeOrDistance(p.targetReps);
}

/// Sugestão para um exercício do treino em andamento, ou `null` se as reps
/// da prescrição não são contáveis, se o exercício é de peso corporal, tempo
/// ou distância, ou se não há histórico com carga. Sem prescrição, usa
/// [defaultFreeWorkoutRule].
ProgressionSuggestion? suggestionForLogged(
  LoggedExercise exercise,
  List<Workout> history, {
  Exercise? library,
}) {
  final prescription = exercise.prescription;
  // Sem plano (treino livre ou exercício adicionado à mão): dupla
  // progressão na faixa padrão de 8 a 12 reps.
  final rule = prescription == null
      ? defaultFreeWorkoutRule
      : ruleForPrescription(prescription);
  if (rule == null) return null;
  return suggestNext(
    rule,
    sessionsFor(exercise.exerciseId, history),
    bodyweight: library?.loadUnit == 'peso do corpo',
    tracksDuration: library?.tracksDuration ?? false,
    tracksDistance: library?.tracksDistance ?? false,
  );
}
