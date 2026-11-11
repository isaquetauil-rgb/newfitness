/// Liga os modelos do app (plano, treino, exercício) à sugestão de carga.
/// Lógica pura: sem Flutter e sem Firebase.
library;

import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';

import 'progression_rule.dart';
import 'suggest_next.dart';

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

/// Sugestão para um exercício do treino em andamento, ou `null` se não há
/// prescrição com reps contáveis, se o exercício é de peso corporal, tempo
/// ou distância, ou se não há histórico com carga.
ProgressionSuggestion? suggestionForLogged(
  LoggedExercise exercise,
  List<Workout> history, {
  Exercise? library,
}) {
  final prescription = exercise.prescription;
  if (prescription == null) return null;
  final rule = ruleForPrescription(prescription);
  if (rule == null) return null;
  return suggestNext(
    rule,
    sessionsFor(exercise.exerciseId, history),
    bodyweight: library?.loadUnit == 'peso do corpo',
    tracksDuration: library?.tracksDuration ?? false,
    tracksDistance: library?.tracksDistance ?? false,
  );
}
