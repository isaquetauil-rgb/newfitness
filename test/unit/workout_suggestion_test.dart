import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/instructor/presentation/plan_editor_screen.dart';
import 'package:newfitness/features/workout/logic/progression/progression_rule.dart';
import 'package:newfitness/features/workout/logic/progression/workout_suggestion.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

const _supino = PlanExercise(
  exerciseId: 'supino',
  exerciseName: 'Supino',
  targetSets: 3,
  targetReps: '8-12',
);

Workout _workout(int day, String id, double kg, List<int> reps) => Workout(
  id: 'w$day',
  userId: 'u1',
  date: DateTime(2026, 1, day),
  exercises: [
    LoggedExercise(
      exerciseId: id,
      exerciseName: id,
      sets: [
        for (final r in reps)
          WorkoutSet(reps: r, weightKg: kg, completed: true),
      ],
    ),
  ],
);

Exercise _lib({String loadUnit = 'kg', bool duration = false}) => Exercise(
  id: 'supino',
  name: 'Supino',
  muscleGroup: '',
  equipment: '',
  description: '',
  videoUrl: '',
  loadUnit: loadUnit,
  tracksDuration: duration,
);

void main() {
  group('ruleForPrescription', () {
    test('sem escolha do personal: deduz pela faixa', () {
      final rule = ruleForPrescription(_supino)!;
      expect(rule.type, ProgressionType.doubleProgression);
      expect(rule.targetSets, 3);
      expect(rule.incrementKg, 2.5);
    });

    test('tipo e incremento do personal', () {
      final rule = ruleForPrescription(
        const PlanExercise(
          exerciseId: 'x',
          exerciseName: 'x',
          targetSets: 3,
          targetReps: '8-12',
          progressionType: 'linear',
          progressionIncrementKg: 5,
        ),
      )!;
      expect(rule.type, ProgressionType.linear);
      expect(rule.maxReps, 12);
      expect(rule.incrementKg, 5);
    });
  });

  test('sessionsFor: só o exercício pedido, mais recente primeiro', () {
    final sessions = sessionsFor('supino', [
      _workout(1, 'supino', 40, [10]),
      _workout(3, 'agacho', 60, [5]),
      _workout(2, 'supino', 42.5, [8]),
    ]);
    expect(sessions.map((s) => s.date.day), [2, 1]);
  });

  group('suggestionForLogged', () {
    final history = [
      _workout(1, 'supino', 40, [12, 12, 12]),
    ];
    LoggedExercise logged([PlanExercise? p = _supino]) => LoggedExercise(
      exerciseId: 'supino',
      exerciseName: 'Supino',
      prescription: p,
    );

    test('com prescrição e histórico: sugere', () {
      final s = suggestionForLogged(logged(), history, library: _lib())!;
      expect(s.weightKg, 42.5);
      expect(s.targetReps, 8);
    });

    test('sem prescrição, peso do corpo ou por tempo: nada', () {
      expect(suggestionForLogged(logged(null), history), isNull);
      expect(
        suggestionForLogged(
          logged(),
          history,
          library: _lib(loadUnit: 'peso do corpo'),
        ),
        isNull,
      );
      expect(
        suggestionForLogged(logged(), history, library: _lib(duration: true)),
        isNull,
      );
    });
  });

  group('PlanExercise: campos de progressão opcionais', () {
    test('plano antigo (sem os campos) continua abrindo', () {
      final p = PlanExercise.fromMap({
        'exerciseId': 'a',
        'exerciseName': 'A',
        'targetSets': 3,
        'targetReps': '10',
      });
      expect(p.progressionType, isNull);
      expect(p.progressionIncrementKg, isNull);
    });

    test('só grava o que o personal escolheu', () {
      expect(_supino.toMap().containsKey('progressionType'), isFalse);
      expect(_supino.toMap().containsKey('progressionIncrementKg'), isFalse);
      final escolhido = PlanExercise.fromMap({
        ..._supino.toMap(),
        'progressionType': 'linear',
        'progressionIncrementKg': 5,
      });
      expect(escolhido.toMap()['progressionType'], 'linear');
      expect(escolhido.toMap()['progressionIncrementKg'], 5.0);
      expect(escolhido.copyWith(exerciseId: 'b').progressionType, 'linear');
    });
  });

  test('editor do personal: incremento de 0,5 a 50 kg', () {
    expect(validatePlanIncrement(2.5), isNull);
    expect(validatePlanIncrement(0.5), isNull);
    expect(validatePlanIncrement(50), isNull);
    expect(validatePlanIncrement(null), isNotNull);
    expect(validatePlanIncrement(0), isNotNull);
    expect(validatePlanIncrement(0.25), isNotNull);
    expect(validatePlanIncrement(51), isNotNull);
  });

  group('WorkoutSet.suggested', () {
    test('só vai para o mapa quando é true', () {
      expect(WorkoutSet(reps: 5).toMap().containsKey('suggested'), isFalse);
      final s = WorkoutSet(reps: 5, weightKg: 40, suggested: true);
      expect(s.toMap()['suggested'], isTrue);
      expect(WorkoutSet.fromMap(s.toMap()).suggested, isTrue);
      expect(s.copy().suggested, isTrue);
    });
  });

  group('WorkoutProvider.prefillSuggestion', () {
    late WorkoutProvider provider;

    setUp(() {
      provider = WorkoutProvider(firestoreService: MockFirestoreService());
      provider.startFromPlan(
        'u1',
        TrainingPlan(
          id: 'p',
          studentUid: 'u1',
          instructorUid: 'i',
          title: 'Plano',
          createdAt: DateTime(2026),
          workouts: [
            const TrainingSubWorkout(label: 'A', exercises: [_supino]),
          ],
        ),
        0,
      );
    });

    List<WorkoutSet> sets() => provider.activeWorkout!.exercises[0].sets;

    test('preenche as séries vazias como sugestão', () {
      provider.prefillSuggestion(0, 42.5, 8);
      expect(sets().every((s) => s.weightKg == 42.5 && s.reps == 8), isTrue);
      expect(sets().every((s) => s.suggested), isTrue);
    });

    test('sugestão intocada não conta como série feita', () {
      provider.prefillSuggestion(0, 42.5, 8);
      final exercises = provider.activeWorkout!.exercises;
      expect(WorkoutProvider.hasRealizedSets(exercises), isFalse);
      expect(WorkoutProvider.withoutEmptySets(exercises).single.sets, isEmpty);
    });

    test('marcar como feita ou editar vira realizado', () {
      provider.prefillSuggestion(0, 42.5, 8);
      provider.updateSet(0, 0, completed: true);
      provider.updateSet(0, 1, reps: 9);
      expect(sets()[0].suggested, isFalse);
      expect(sets()[1].suggested, isFalse);
      expect(sets()[2].suggested, isTrue);
      final kept = WorkoutProvider.withoutEmptySets(
        provider.activeWorkout!.exercises,
      ).single.sets;
      expect(kept, hasLength(2));
      provider.skipRest();
    });

    test('não sobrescreve o que o aluno já digitou e só preenche uma vez', () {
      provider.updateSet(0, 0, weightKg: 50);
      provider.prefillSuggestion(0, 42.5, 8);
      expect(sets()[0].weightKg, 50);
      expect(sets()[0].suggested, isFalse);

      // Apagou os campos: não volta a preencher.
      provider.updateSet(0, 1, weightKg: 0, reps: 0);
      provider.prefillSuggestion(0, 42.5, 8);
      expect(sets()[1].weightKg, 0);
    });
  });
}
