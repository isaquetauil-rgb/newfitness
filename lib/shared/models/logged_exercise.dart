import 'training_plan.dart';
import 'workout_set.dart';

/// Um exercício dentro de um treino em andamento (ou já concluído),
/// junto com todas as séries realizadas.
///
/// Separa o PRESCRITO do REALIZADO:
///  - [sets] é exclusivamente o que o aluno fez (nunca preenchido a partir
///    da prescrição) — é daqui que saem volume, carga e progresso;
///  - [prescription] é a meta do plano, só orientação.
class LoggedExercise {
  final String exerciseId;
  final String exerciseName;
  final List<WorkoutSet> sets;

  /// Preenchido quando este exercício substituiu outro (ver "Trocar
  /// exercício" em `WorkoutScreen`/`WorkoutProvider.substituteExercise`) —
  /// guarda o exercício originalmente adicionado/prescrito, não o
  /// imediatamente anterior, então uma segunda troca continua apontando
  /// para a origem da cadeia. `null` quando nunca foi trocado.
  final String? replacedExerciseId;
  final String? replacedExerciseName;

  /// Cópia CONGELADA do exercício do plano no momento em que o treino
  /// começou (ver `WorkoutProvider.startFromPlan`) — séries, reps, carga,
  /// descanso e orientação prescritos. `null` em treino livre, em
  /// exercícios adicionados à mão e em treinos antigos.
  ///
  /// Numa troca de exercício durante o treino, continua sendo a prescrição
  /// do exercício ORIGINAL (`prescription.exerciseId` pode ser diferente de
  /// [exerciseId]). Ser uma cópia (e não uma referência ao plano) mantém o
  /// histórico fiel mesmo se o plano for editado ou apagado depois.
  final PlanExercise? prescription;

  LoggedExercise({
    required this.exerciseId,
    required this.exerciseName,
    List<WorkoutSet>? sets,
    this.replacedExerciseId,
    this.replacedExerciseName,
    this.prescription,
  }) : sets = sets ?? [WorkoutSet()];

  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + (s.reps * s.weightKg));

  /// A prescrição é deste mesmo exercício (e não de um que foi trocado)?
  bool get prescriptionMatchesExercise =>
      prescription != null && prescription!.exerciseId == exerciseId;

  /// Cópia com [sets] no lugar das séries atuais — o resto (inclusive a
  /// prescrição) é mantido.
  LoggedExercise copyWith({List<WorkoutSet>? sets}) {
    return LoggedExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      sets: sets ?? this.sets,
      replacedExerciseId: replacedExerciseId,
      replacedExerciseName: replacedExerciseName,
      prescription: prescription,
    );
  }

  factory LoggedExercise.fromMap(Map<String, dynamic> map) {
    final rawPrescription = map['prescription'];
    return LoggedExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      sets:
          (map['sets'] as List<dynamic>?)
              ?.map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [WorkoutSet()],
      replacedExerciseId: map['replacedExerciseId'] as String?,
      replacedExerciseName: map['replacedExerciseName'] as String?,
      prescription: rawPrescription is Map
          ? PlanExercise.fromMap(Map<String, dynamic>.from(rawPrescription))
          : null,
    );
  }

  /// `prescription` é omitido quando nulo (treino livre/antigo).
  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'sets': sets.map((s) => s.toMap()).toList(),
      'replacedExerciseId': replacedExerciseId,
      'replacedExerciseName': replacedExerciseName,
      'prescription': ?prescription?.toMap(),
    };
  }
}
