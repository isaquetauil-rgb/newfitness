import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/workout/logic/progression/progression_rule.dart';
import 'package:newfitness/features/workout/logic/progression/suggest_next.dart';
import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';
import 'package:newfitness/features/workout/logic/warmup.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

import '../helpers/mocks.dart';

WorkoutSet _s(double kg, int reps, [SetType type = SetType.normal]) =>
    WorkoutSet(weightKg: kg, reps: reps, completed: true, type: type);

PlanExercise _p(String id, {String? group, int rest = 60}) => PlanExercise(
  exerciseId: id,
  exerciseName: id,
  targetSets: 2,
  targetReps: '10',
  restSeconds: rest,
  supersetGroup: group,
);

void main() {
  group('tipo da série', () {
    test('dados antigos (sem type) são normal; só grava quando não é', () {
      final old = WorkoutSet.fromMap({
        'reps': 10,
        'weightKg': 40,
        'completed': true,
      });
      expect(old.type, SetType.normal);
      expect(old.toMap().containsKey('type'), isFalse);
      for (final t in SetType.values) {
        final s = WorkoutSet(reps: 5, type: t);
        expect(WorkoutSet.fromMap(s.toMap()).type, t);
        expect(s.copy().type, t);
      }
      expect(setTypeFromString('qualquer'), SetType.normal);
    });

    test('aquecimento fica fora do volume', () {
      final e = LoggedExercise(
        exerciseId: 'a',
        exerciseName: 'A',
        sets: [_s(20, 10, SetType.warmup), _s(50, 10), _s(40, 8, SetType.drop)],
      );
      expect(e.totalVolume, 500 + 320);
    });

    test('aquecimento fica fora da carga de topo e do 1RM', () {
      final sets = [_s(100, 3, SetType.warmup), _s(60, 5)];
      expect(bestLoad(sets), 60);
      expect(bestE1rm(sets), closeTo(70, 1e-9));
      final agg = aggregateProgressInputs([
        LoggedExercise(exerciseId: 'a', exerciseName: 'A', sets: sets),
      ]);
      expect(agg['a']!.topSetLoadKg, 60);
    });

    test('série de aquecimento nunca é recorde', () {
      const base = RecordBaseline(bestLoadKg: 50, bestE1rmKg: 60);
      final w = _s(80, 5, SetType.warmup);
      expect(detectSetRecords(w, [w], base), isEmpty);
      final f = _s(80, 5, SetType.failure);
      expect(detectSetRecords(f, [f], base), isNotEmpty);
    });

    test('progressão ignora aquecimento e drop', () {
      final rule = ProgressionRule.fromTargetReps('8-12', targetSets: 3)!;
      final s = suggestNext(rule, [
        ExerciseSession(
          date: DateTime(2026),
          sets: [
            _s(20, 10, SetType.warmup),
            _s(30, 6, SetType.warmup),
            _s(40, 12),
            _s(40, 12),
            _s(40, 12),
            _s(25, 8, SetType.drop),
          ],
        ),
      ])!;
      // Sem o filtro, o drop (8 reps) e o aquecimento travariam a subida.
      expect(s.weightKg, 42.5);
    });
  });

  group('generateWarmupSets', () {
    List<(double, int)> v(List<WorkoutSet> s) => [
      for (final x in s) (x.weightKg, x.reps),
    ];

    test('100 kg: 40%, 60% e 80%', () {
      final w = generateWarmupSets(100);
      expect(v(w), [(40.0, 10), (60.0, 6), (80.0, 3)]);
      expect(w.every((s) => s.isWarmup && !s.completed), isTrue);
    });

    test('arredonda pelas anilhas (2,5 kg)', () {
      expect(v(generateWarmupSets(62.5)), [(25.0, 10), (37.5, 6), (50.0, 3)]);
    });

    test('abaixo de 40 kg: duas séries (50% e 75%)', () {
      expect(v(generateWarmupSets(30)), [(15.0, 8), (22.5, 4)]);
    });

    test('cargas pequenas: passo de 0,5 kg, sem repetir nem zerar', () {
      expect(v(generateWarmupSets(10)), [(5.0, 8), (7.5, 4)]);
      expect(v(generateWarmupSets(1)), [(0.5, 8)]);
      expect(generateWarmupSets(0), isEmpty);
    });
  });

  test('groupSupersets junta o grupo na posição do primeiro', () {
    final ordered = groupSupersets([
      _p('a', group: 'A'),
      _p('x'),
      _p('b', group: 'A'),
      _p('c', group: 'B'),
      _p('y'),
      _p('d', group: 'B'),
    ]);
    expect(ordered.map((e) => e.exerciseId), ['a', 'b', 'x', 'c', 'd', 'y']);
    expect(supersetLabel('A', 2), 'Bi-set A');
    expect(supersetLabel('A', 3), 'Tri-set A');
  });

  test('supersetGroup é opcional no plano', () {
    expect(_p('a').toMap().containsKey('supersetGroup'), isFalse);
    final g = PlanExercise.fromMap(_p('a', group: 'B').toMap());
    expect(g.supersetGroup, 'B');
    expect(g.copyWith(exerciseId: 'z').supersetGroup, 'B');
  });

  group('WorkoutProvider', () {
    late RestTimerController timer;
    late WorkoutProvider provider;

    WorkoutProvider start(List<PlanExercise> exercises) {
      timer = RestTimerController();
      provider = WorkoutProvider(
        firestoreService: MockFirestoreService(),
        restTimer: timer,
        keepScreenOn: (_) async {},
      );
      provider.startFromPlan(
        'u1',
        TrainingPlan(
          id: 'p',
          studentUid: 'u1',
          instructorUid: 'i',
          title: 'P',
          createdAt: DateTime(2026),
          workouts: [TrainingSubWorkout(label: 'A', exercises: exercises)],
        ),
        0,
      );
      return provider;
    }

    tearDown(() => timer.skip());

    test('gerar aquecimento: antes da primeira série, a partir da carga', () {
      start([_p('supino')]);
      expect(provider.generateWarmup(0), 0); // sem carga ainda
      provider.updateSet(0, 0, weightKg: 60, reps: 10);
      expect(provider.generateWarmup(0), 3);
      final sets = provider.activeWorkout!.exercises[0].sets;
      expect(sets.map((s) => s.type), [
        SetType.warmup,
        SetType.warmup,
        SetType.warmup,
        SetType.normal,
        SetType.normal,
      ]);
      expect(sets.first.weightKg, 25); // 40% de 60 = 24 → 25

      // Gerar de novo substitui o aquecimento não feito.
      provider.updateSet(0, 3, weightKg: 100);
      provider.generateWarmup(0);
      final again = provider.activeWorkout!.exercises[0].sets;
      expect(again.where((s) => s.isWarmup).map((s) => s.weightKg), [
        40,
        60,
        80,
      ]);
      expect(again, hasLength(5));
    });

    test('trocar tipo da série', () {
      start([_p('supino')]);
      provider.setSetType(0, 1, SetType.drop);
      expect(provider.activeWorkout!.exercises[0].sets[1].type, SetType.drop);
    });

    test('bi-set: exercícios juntos e descanso só depois do último', () {
      start([_p('a', group: 'A'), _p('x'), _p('b', group: 'A', rest: 90)]);
      final ids = [
        for (final e in provider.activeWorkout!.exercises) e.exerciseId,
      ];
      expect(ids, ['a', 'b', 'x']);
      expect(provider.supersetMembers(0), [0, 1]);

      provider.updateSet(0, 0, completed: true);
      expect(timer.isActive, isFalse);
      provider.updateSet(1, 0, completed: true);
      expect(timer.remainingSeconds, inInclusiveRange(89, 90));

      timer.skip();
      provider.updateSet(2, 0, completed: true); // fora do grupo
      expect(timer.isActive, isTrue);
    });
  });
}
