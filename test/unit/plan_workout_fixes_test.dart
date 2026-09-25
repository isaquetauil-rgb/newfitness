import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/instructor/presentation/plan_editor_screen.dart';
import 'package:newfitness/features/workout/data/active_workout_store.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

/// Ajustes da auditoria da prescrição (#14): progresso sem ID, troca
/// A → B → A, validação do exercício no plano e treino de plano encerrado
/// sem nenhuma série realizada.
void main() {
  setUpAll(registerTestFallbackValues);

  LoggedExercise done(String id, {double kg = 10, int reps = 10}) =>
      LoggedExercise(
        exerciseId: id,
        exerciseName: id.isEmpty ? 'Sugestão da IA' : id,
        sets: [WorkoutSet(reps: reps, weightKg: kg, completed: true)],
      );

  group('1. progresso ignora exercícios sem ID', () {
    test('sem ID ANTES dos válidos', () {
      final r = aggregateProgressInputs([done(''), done('a'), done('b')]);
      expect(r.keys, ['a', 'b']);
    });

    test('sem ID ENTRE os válidos', () {
      final r = aggregateProgressInputs([done('a'), done(''), done('b')]);
      expect(r.keys, ['a', 'b']);
    });

    test('sem ID NO FINAL', () {
      final r = aggregateProgressInputs([done('a'), done('b'), done('')]);
      expect(r.keys, ['a', 'b']);
    });

    test('vários sem ID (inclusive só espaços) não viram um exercício só', () {
      final r = aggregateProgressInputs([
        done('', kg: 50),
        done('   ', kg: 60),
        done('a', kg: 20),
        done(''),
      ]);
      expect(r.keys, ['a']);
      expect(r.containsKey(''), isFalse);
      expect(r.containsKey('   '), isFalse);
    });

    test('válidos continuam registrando normalmente (valores intactos)', () {
      final r = aggregateProgressInputs([
        done(''),
        done('a', kg: 30, reps: 8),
        done('a', kg: 32, reps: 6),
      ]);
      expect(r['a']!.topSetLoadKg, 32);
      expect(r['a']!.totalVolume, 30 * 8 + 32 * 6);
    });
  });

  group('2. troca A → B → A desfaz a substituição', () {
    late WorkoutProvider provider;
    const b = Exercise(
      id: 'b',
      name: 'B',
      muscleGroup: '',
      equipment: '',
      description: '',
      videoUrl: '',
    );
    const a = Exercise(
      id: 'a',
      name: 'A',
      muscleGroup: '',
      equipment: '',
      description: '',
      videoUrl: '',
    );
    const c = Exercise(
      id: 'c',
      name: 'C',
      muscleGroup: '',
      equipment: '',
      description: '',
      videoUrl: '',
    );
    final plan = TrainingPlan(
      id: 'p',
      studentUid: 'u1',
      instructorUid: 'i1',
      title: 'Plano',
      createdAt: DateTime(2024),
      workouts: const [
        TrainingSubWorkout(
          label: 'A',
          exercises: [
            PlanExercise(
              exerciseId: 'a',
              exerciseName: 'A',
              targetSets: 3,
              targetReps: '10',
            ),
          ],
        ),
      ],
    );

    setUp(() {
      provider = WorkoutProvider(firestoreService: MockFirestoreService());
      provider.startFromPlan('u1', plan, 0);
    });

    LoggedExercise current() => provider.activeWorkout!.exercises.single;

    test('A → B continua registrando a troca', () {
      provider.substituteExercise(0, b);
      expect(current().exerciseId, 'b');
      expect(current().replacedExerciseId, 'a');
      expect(current().replacedExerciseName, 'A');
    });

    test('A → B → A: troca desfeita, prescrição original correta', () {
      provider.updateSet(0, 0, reps: 10, weightKg: 20, completed: true);
      provider.substituteExercise(0, b);
      provider.substituteExercise(0, a);

      expect(current().exerciseId, 'a');
      expect(current().exerciseName, 'A');
      expect(current().replacedExerciseId, isNull);
      expect(current().replacedExerciseName, isNull);
      expect(current().prescription!.exerciseId, 'a');
      expect(current().prescriptionMatchesExercise, isTrue);
      expect(current().sets.first.reps, 10); // séries preservadas
    });

    test('A → B → C continua apontando para a origem A', () {
      provider.substituteExercise(0, b);
      provider.substituteExercise(0, c);
      expect(current().exerciseId, 'c');
      expect(current().replacedExerciseId, 'a');
      expect(current().prescription!.exerciseId, 'a');
    });

    test('A → B → A → C volta a registrar a troca a partir de A', () {
      provider.substituteExercise(0, b);
      provider.substituteExercise(0, a);
      provider.substituteExercise(0, c);
      expect(current().replacedExerciseId, 'a');
    });
  });

  group('3. validação do exercício no plano', () {
    test('séries válidas: 1 e 20', () {
      expect(validatePlanSets(1), isNull);
      expect(validatePlanSets(20), isNull);
    });

    test('séries inválidas: 0, -1, 21, vazio/texto', () {
      expect(validatePlanSets(0), isNotNull);
      expect(validatePlanSets(-1), isNotNull);
      expect(validatePlanSets(21), isNotNull);
      expect(validatePlanSets(null), isNotNull);
    });

    test('descanso: 0 é válido; -1 e vazio/texto não', () {
      expect(validatePlanRest(0), isNull);
      expect(validatePlanRest(600), isNull);
      expect(validatePlanRest(-1), isNotNull);
      expect(validatePlanRest(null), isNotNull);
    });
  });

  group('4. treino de plano encerrado sem nenhuma série realizada', () {
    late MockFirestoreService firestoreService;
    late WorkoutProvider provider;
    final plan = TrainingPlan(
      id: 'plan1',
      studentUid: 'u1',
      instructorUid: 'i1',
      title: 'Hipertrofia',
      createdAt: DateTime(2024),
      workouts: const [
        TrainingSubWorkout(
          label: 'Treino A',
          exercises: [
            PlanExercise(
              exerciseId: 'supino',
              exerciseName: 'Supino',
              targetSets: 3,
              targetReps: '10',
              targetWeightsKg: '30',
            ),
            PlanExercise(
              exerciseId: 'flexao',
              exerciseName: 'Flexão',
              targetSets: 2,
              targetReps: '15',
            ),
          ],
        ),
      ],
    );

    setUp(() {
      firestoreService = MockFirestoreService();
      when(() => firestoreService.saveWorkout(any()))
          .thenAnswer((_) async => 'w');
      when(() => firestoreService.recordExerciseProgress(any()))
          .thenAnswer((_) async {});
      provider = WorkoutProvider(firestoreService: firestoreService);
    });

    test(
      '4.1 / 4.5 nenhuma série realizada: não grava sessão nem progresso',
      () async {
        provider.startFromPlan('u1', plan, 0);
        // exercício adicionado à mão, também vazio
        provider.addExercise(
          const Exercise(
            id: 'extra',
            name: 'Extra',
            muscleGroup: '',
            equipment: '',
            description: '',
            videoUrl: '',
          ),
        );

        final result = await provider.finishWorkout();

        expect(result, WorkoutFinishResult.endedWithoutSets);
        expect(provider.hasActiveWorkout, isFalse);
        expect(provider.isSaving, isFalse);
        verifyNever(() => firestoreService.saveWorkout(any()));
        verifyNever(() => firestoreService.recordExerciseProgress(any()));
      },
    );

    test('4.2 uma série com reps > 0 (sem concluir) gera sessão', () async {
      provider.startFromPlan('u1', plan, 0);
      provider.updateSet(0, 0, reps: 8);

      expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
      verify(() => firestoreService.saveWorkout(any())).called(1);
    });

    test('4.3 uma série com peso > 0 (sem concluir) gera sessão', () async {
      provider.startFromPlan('u1', plan, 0);
      provider.updateSet(0, 1, weightKg: 20);

      expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
      verify(() => firestoreService.saveWorkout(any())).called(1);
    });

    test(
      '4.4 concluída com 0 reps e 0 kg conta como realizada (peso do corpo)',
      () async {
        provider.startFromPlan('u1', plan, 0);
        provider.updateSet(1, 0, completed: true);

        expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
        final saved =
            verify(() => firestoreService.saveWorkout(captureAny()))
                    .captured
                    .single
                as dynamic;
        expect(saved.exercises[1].sets, hasLength(1));
        expect(saved.exercises[0].sets, isEmpty);
      },
    );

    test('4.6 rascunho local é apagado ao encerrar sem séries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = LocalPrefs(await SharedPreferences.getInstance());
      final store = ActiveWorkoutStore(prefs);
      final p = WorkoutProvider(
        firestoreService: firestoreService,
        store: store,
      )..startFromPlan('u1', plan, 0);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.activeWorkoutJson, isNotNull);

      expect(await p.finishWorkout(), WorkoutFinishResult.endedWithoutSets);

      expect(prefs.activeWorkoutJson, isNull);
      final reopened = WorkoutProvider(
        firestoreService: firestoreService,
        store: store,
      );
      expect(await reopened.restoreFor('u1'), isFalse);
    });

    test(
      '4.6b restaurar → continuar → finalizar mantém origem/prescrição',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = LocalPrefs(await SharedPreferences.getInstance());
        final store = ActiveWorkoutStore(prefs);
        WorkoutProvider(
          firestoreService: firestoreService,
          store: store,
        ).startFromPlan('u1', plan, 0);
        await Future<void>.delayed(Duration.zero);

        final reopened = WorkoutProvider(
          firestoreService: firestoreService,
          store: store,
        );
        expect(await reopened.restoreFor('u1'), isTrue);
        reopened.updateSet(0, 0, reps: 10, weightKg: 30, completed: true);

        expect(await reopened.finishWorkout(), WorkoutFinishResult.saved);
        final saved =
            verify(() => firestoreService.saveWorkout(captureAny()))
                    .captured
                    .single
                as dynamic;
        expect(saved.source.planId, 'plan1');
        expect(saved.exercises[0].prescription.targetWeightsKg, '30');
        await Future<void>.delayed(Duration.zero);
        expect(prefs.activeWorkoutJson, isNull);
      },
    );
  });

  group('5. treino LIVRE: mesma regra (só grava com série realizada)', () {
    late MockFirestoreService firestoreService;
    late WorkoutProvider provider;
    const exercise = Exercise(
      id: 'rosca',
      name: 'Rosca',
      muscleGroup: '',
      equipment: '',
      description: '',
      videoUrl: '',
    );

    setUp(() {
      firestoreService = MockFirestoreService();
      when(() => firestoreService.saveWorkout(any()))
          .thenAnswer((_) async => 'w');
      when(() => firestoreService.recordExerciseProgress(any()))
          .thenAnswer((_) async {});
      provider = WorkoutProvider(firestoreService: firestoreService)
        ..startWorkout('u1')
        ..addExercise(exercise)
        ..addExercise(exercise);
    });

    test(
      'livre sem séries realizadas: não grava treino nem progresso',
      () async {
        expect(
          await provider.finishWorkout(),
          WorkoutFinishResult.endedWithoutSets,
        );
        expect(provider.hasActiveWorkout, isFalse);
        verifyNever(() => firestoreService.saveWorkout(any()));
        verifyNever(() => firestoreService.recordExerciseProgress(any()));
      },
    );

    test('livre com reps: grava e registra progresso', () async {
      provider.updateSet(0, 0, reps: 12);

      expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
      verify(() => firestoreService.saveWorkout(any())).called(1);
      verify(() => firestoreService.recordExerciseProgress(any())).called(1);
    });

    test('livre com carga: grava', () async {
      provider.updateSet(1, 0, weightKg: 14);

      expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
      verify(() => firestoreService.saveWorkout(any())).called(1);
    });

    test('livre com série concluída e 0 kg: grava (peso do corpo)', () async {
      provider.updateSet(0, 0, completed: true);

      expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
      final saved =
          verify(() => firestoreService.saveWorkout(captureAny()))
                  .captured
                  .single
              as dynamic;
      expect(saved.exercises[0].sets, hasLength(1));
      expect(saved.exercises[1].sets, isEmpty); // limpeza inalterada
    });

    test('livre vazio: rascunho local apagado ao encerrar', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = LocalPrefs(await SharedPreferences.getInstance());
      final store = ActiveWorkoutStore(prefs);
      final p =
          WorkoutProvider(firestoreService: firestoreService, store: store)
            ..startWorkout('u1')
            ..addExercise(exercise);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.activeWorkoutJson, isNotNull);

      expect(await p.finishWorkout(), WorkoutFinishResult.endedWithoutSets);

      expect(prefs.activeWorkoutJson, isNull);
      expect(
        await WorkoutProvider(
          firestoreService: firestoreService,
          store: store,
        ).restoreFor('u1'),
        isFalse,
      );
    });
  });
}
