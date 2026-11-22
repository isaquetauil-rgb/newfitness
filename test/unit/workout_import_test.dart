import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/features/import/logic/workout_csv_parser.dart';
import 'package:newfitness/features/import/logic/workout_import.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_functional_exercises.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

String _fixture(String name) =>
    File('test/fixtures/import/$name').readAsStringSync();

final _pool = [...sampleExercises, ...sampleFunctionalExercises];

void main() {
  group('Hevy', () {
    final r = parseWorkoutCsv(_fixture('hevy_exemplo.csv'));

    test('reconhece o formato e agrupa por treino', () {
      expect(r.source, ImportSource.hevy);
      expect(r.workouts, hasLength(2));
      expect(r.unitFromFile, isTrue);
      final push = r.workouts.first;
      expect(push.title, 'Push A');
      expect(push.start, DateTime(2026, 1, 15, 18, 2));
      expect(push.durationSeconds, 68 * 60);
      expect(push.exercises.map((e) => e.name), [
        'Bench Press (Barbell)',
        'Lateral Raise (Dumbbell)',
        'Plank',
      ]);
    });

    test('tipos de série, carga e tempo', () {
      final push = r.workouts.first;
      final bench = push.exercises[0].sets;
      expect(bench.map((s) => s.type), [
        SetType.warmup,
        SetType.normal,
        SetType.failure,
      ]);
      expect(bench[1].weightKg, 62.5);
      expect(bench[1].reps, 8);
      expect(push.exercises[1].sets[1].type, SetType.drop);
      // Prancha: 60 s; a série vazia foi ignorada.
      expect(push.exercises[2].sets.single.seconds, 60);
      expect(r.skippedRows, 1);
    });

    test('título com vírgula e aspas', () {
      expect(r.workouts[1].title, 'Pernas, dia "pesado"');
    });

    test('datas do Hevy', () {
      expect(parseHevyDate('29 Mar 2024, 18:02'), DateTime(2024, 3, 29, 18, 2));
      expect(parseHevyDate('5 fev 2024, 07:05'), DateTime(2024, 2, 5, 7, 5));
      expect(
        parseHevyDate('2024-03-29T18:02:00'),
        DateTime(2024, 3, 29, 18, 2),
      );
      expect(parseHevyDate('ontem'), isNull);
    });

    test('Hevy em libras converte para kg', () {
      const csv =
          'title,start_time,end_time,exercise_title,set_type,weight_lbs,reps\n'
          'A,1 Jan 2026 10:00,1 Jan 2026 11:00,Squat (Barbell),normal,225,5\n';
      final s = parseWorkoutCsv(csv).workouts.single.exercises.single.sets;
      expect(s.single.weightKg, 102.1);
    });
  });

  group('Strong', () {
    test('vírgula: W = aquecimento, descanso ignorado, duração', () {
      final r = parseWorkoutCsv(_fixture('strong_exemplo.csv'));
      expect(r.source, ImportSource.strong);
      expect(r.unitFromFile, isFalse);
      expect(r.workouts.map((w) => w.title), ['Treino B', 'Treino A']);
      final b = r.workouts.first;
      expect(b.durationSeconds, 65 * 60);
      expect(b.exercises.first.sets.map((s) => s.type), [
        SetType.warmup,
        SetType.normal,
        SetType.normal,
      ]);
      expect(b.exercises.first.sets[1].weightKg, 120);
      expect(r.skippedRows, 1); // "Rest Timer"
      expect(r.workouts[1].durationSeconds, 45 * 60);
    });

    test('unidade escolhida (lb) quando o arquivo não diz', () {
      final r = parseWorkoutCsv(
        _fixture('strong_exemplo.csv'),
        strongUnit: WeightUnit.lb,
      );
      expect(r.workouts.first.exercises.first.sets[1].weightKg, 54.4);
    });

    test('ponto e vírgula, vírgula decimal e coluna de unidade', () {
      final r = parseWorkoutCsv(_fixture('strong_ponto_e_virgula.csv'));
      expect(r.unitFromFile, isTrue);
      final sets = r.workouts.single.exercises.single.sets;
      expect(sets[0].weightKg, 61.2); // 135 lb
      expect(sets[1].weightKg, 61.5); // 61,5 kg
    });

    test('duração do Strong', () {
      expect(parseStrongDuration('1h 8m'), 4080);
      expect(parseStrongDuration('45m'), 2700);
      expect(parseStrongDuration('38s'), 38);
      expect(parseStrongDuration(''), 0);
    });
  });

  test('arquivo desconhecido ou vazio', () {
    expect(
      () => parseWorkoutCsv('nome,idade\nAna,30\n'),
      throwsA(isA<FormatException>()),
    );
    expect(() => parseWorkoutCsv(''), throwsA(isA<FormatException>()));
  });

  group('casamento de nomes (exercise_similarity)', () {
    String? best(String name) {
      final m = matchExercisesByName(name, _pool, limit: 1);
      return m.isEmpty || m.first.score < autoNameMatchScore
          ? null
          : m.first.exercise.id;
    }

    test('nomes do Hevy/Strong caem no exercício certo', () {
      expect(best('Bench Press (Barbell)'), 'bench_press');
      expect(best('Bench Press (Dumbbell)'), 'dumbbell_bench_press');
      expect(best('Squat (Barbell)'), 'squat');
      expect(best('Deadlift (Barbell)'), 'deadlift');
      expect(best('Lat Pulldown (Cable)'), 'lat_pulldown');
      expect(best('Lateral Raise (Dumbbell)'), 'lateral_raise');
      expect(best('Bulgarian Split Squat'), 'bulgarian_split_squat');
      expect(best('Plank'), 'plank');
      expect(best('Pull Up'), 'pull_up');
      expect(best('Triceps Pushdown (Cable)'), 'triceps_pushdown');
      expect(best('Seated Cable Row'), 'seated_cable_row');
    });

    test('nome em português também casa', () {
      expect(best('Supino reto'), 'bench_press');
      expect(best('Cadeira extensora'), 'leg_extension');
    });

    test('nome sem parecido fica para o aluno escolher', () {
      expect(best('Zercher Carry Esquisito'), isNull);
      expect(matchExercisesByName('(Barbell)', _pool), isEmpty);
    });
  });

  group('montar e não duplicar', () {
    final parsed = parseWorkoutCsv(_fixture('hevy_exemplo.csv'));
    Map<String, ImportChoice> allChoices() {
      final c = suggestChoices(parsed.exerciseNames, _pool);
      c['Zercher Carry Esquisito'] = ImportChoice.own(
        'Zercher Carry Esquisito',
        muscleGroup: 'Pernas',
      );
      return c;
    }

    test('sugestões automáticas deixam de fora só o desconhecido', () {
      final c = suggestChoices(parsed.exerciseNames, _pool);
      expect(c.keys, isNot(contains('Zercher Carry Esquisito')));
      expect(c['Bench Press (Barbell)']!.exerciseId, 'bench_press');
      expect(c['Bench Press (Barbell)']!.exerciseName, 'Supino reto');
    });

    test('treinos marcados como importados, séries concluídas', () {
      final plan = buildImport(
        parsed,
        allChoices(),
        userId: 'u',
        history: const [],
      );
      expect(plan.toSave, hasLength(2));
      expect(plan.duplicates, 0);
      final w = plan.toSave.first;
      expect(w.isImported, isTrue);
      expect(w.importedFrom, 'hevy');
      expect(w.id, startsWith('import_hevy_'));
      expect(w.exercises.first.exerciseName, 'Supino reto');
      expect(w.exercises.first.sets.every((s) => s.completed), isTrue);
      final own = plan.toSave[1].exercises.last;
      expect(own.exerciseId, 'own_zercher_carry_esquisito');
      expect(own.exerciseName, 'Zercher Carry Esquisito');
      expect(own.muscleGroup, 'Pernas');
      // Exercício da biblioteca não grava grupo no treino.
      expect(w.exercises.first.muscleGroup, isNull);
      // Volume ignora o aquecimento, como no resto do app.
      expect(w.exercises.first.totalVolume, 62.5 * 8 + 62.5 * 6);
    });

    test('reimportar o mesmo arquivo não duplica', () {
      final first = buildImport(
        parsed,
        allChoices(),
        userId: 'u',
        history: const [],
      );
      // Mesmo id ou mesma chave já no histórico.
      final again = buildImport(
        parseWorkoutCsv(_fixture('hevy_exemplo.csv')),
        allChoices(),
        userId: 'u',
        history: first.toSave,
      );
      expect(again.toSave, isEmpty);
      expect(again.duplicates, 2);

      final byKeyOnly = [
        Workout(
          id: 'outro-id',
          userId: 'u',
          date: DateTime(2026),
          importKey: first.toSave.first.importKey,
        ),
      ];
      final partial = buildImport(
        parsed,
        allChoices(),
        userId: 'u',
        history: byKeyOnly,
      );
      expect(partial.toSave, hasLength(1));
      expect(partial.duplicates, 1);
    });

    test('ids estáveis e diferentes por treino', () {
      final a = buildImport(
        parsed,
        allChoices(),
        userId: 'u',
        history: const [],
      );
      final b = buildImport(
        parsed,
        allChoices(),
        userId: 'u',
        history: const [],
      );
      expect(a.toSave.map((w) => w.id), b.toSave.map((w) => w.id));
      expect(a.toSave[0].id, isNot(a.toSave[1].id));
    });

    test('falta escolher um exercício: erro', () {
      expect(
        () => buildImport(
          parsed,
          suggestChoices(parsed.exerciseNames, _pool),
          userId: 'u',
          history: const [],
        ),
        throwsArgumentError,
      );
    });

    test('Workout antigo (sem os campos novos) continua abrindo', () {
      final w = Workout.fromMap('x', {'userId': 'u', 'date': 0});
      expect(w.isImported, isFalse);
      expect(w.toMap().containsKey('importedFrom'), isFalse);
      final back = Workout.fromMap('x', {
        'userId': 'u',
        'date': 0,
        'importedFrom': 'strong',
        'importKey': 'k',
      });
      expect(back.importedFrom, 'strong');
      expect(back.importKey, 'k');
    });
  });

  test('recorde: treino importado mais antigo não muda a "última carga"', () {
    final recent = ExerciseProgressRecord.merge(
      existing: null,
      exerciseId: 'bench_press',
      exerciseName: 'Supino reto',
      date: DateTime(2026, 3, 1),
      topSetLoadKg: 60,
      totalVolume: 1000,
    );
    final withOld = ExerciseProgressRecord.merge(
      existing: recent,
      exerciseId: 'bench_press',
      exerciseName: 'Supino reto',
      date: DateTime(2025, 1, 1),
      topSetLoadKg: 70,
      totalVolume: 900,
    );
    expect(withOld.lastLoadKg, 60);
    expect(withOld.lastPerformedAt, DateTime(2026, 3, 1));
    expect(withOld.bestLoadKg, 70);
    expect(withOld.totalSessions, 2);
    expect(withOld.history.first.date, DateTime(2025, 1, 1));
  });

  group('não descarta dados (distância, tempo, RPE, anotações)', () {
    test('Hevy: RPE, anotações do exercício e do treino, distância', () {
      final r = parseWorkoutCsv(_fixture('hevy_exemplo.csv'));
      final push = r.workouts.first;
      final bench = push.exercises.first.sets;
      expect(bench[1].rpe, 8);
      expect(bench[2].rpe, 10);
      expect(bench[0].rpe, isNull);

      final pernas = r.workouts[1];
      expect(pernas.notes, 'Sábado cedo');
      final squat = pernas.exercises.first;
      expect(squat.sets.first.notes, 'Descer bem'); // só na 1ª série
      expect(squat.sets[1].notes, isNull);
      final farmer = pernas.exercises.firstWhere(
        (e) => e.name == 'Farmer Walk (Dumbbell)',
      );
      expect(farmer.sets.single.distanceMeters, 40);
      expect(farmer.sets.single.seconds, 60);
      expect(farmer.sets.single.weightKg, 24);
      expect(farmer.sets.single.notes, 'Pegada firme');
    });

    test('Strong: anotação da série, do treino, RPE e distância', () {
      final r = parseWorkoutCsv(_fixture('strong_exemplo.csv'));
      final b = r.workouts.first;
      expect(b.notes, 'Dia bom');
      expect(b.exercises.first.sets[1].rpe, 8);
      final pulldown = b.exercises[1].sets;
      expect(pulldown[1].notes, 'Pegada aberta, "devagar"');
      final a = r.workouts[1];
      final farmer = a.exercises.last.sets.single;
      expect(farmer.distanceMeters, 40);
      expect(farmer.seconds, 60);
      expect(farmer.rpe, 7.5);
    });

    test('Hevy em milhas', () {
      const csv =
          'title,start_time,end_time,exercise_title,set_type,distance_miles,duration_seconds\n'
          'Corrida,1 Jan 2026 10:00,1 Jan 2026 10:30,Running,normal,1,600\n';
      final s = parseWorkoutCsv(csv).workouts.single.exercises.single.sets;
      expect(s.single.distanceMeters, 1609.3);
    });

    test('série só com distância não é descartada', () {
      const csv =
          'title,start_time,end_time,exercise_title,set_type,distance_km\n'
          'Remo,1 Jan 2026 10:00,1 Jan 2026 10:30,Rowing,normal,2\n';
      final s = parseWorkoutCsv(csv).workouts.single.exercises.single.sets;
      expect(s.single.distanceMeters, 2000);
    });

    test('RPE fora de 1 a 10 é ignorado', () {
      const csv =
          'title,start_time,end_time,exercise_title,set_type,weight_kg,reps,rpe\n'
          'A,1 Jan 2026 10:00,1 Jan 2026 11:00,Squat (Barbell),normal,100,5,42\n';
      final s = parseWorkoutCsv(csv).workouts.single.exercises.single.sets;
      expect(s.single.rpe, isNull);
    });

    test('vai para o treino salvo e volta do Firestore', () {
      final parsed = parseWorkoutCsv(_fixture('hevy_exemplo.csv'));
      final c = suggestChoices(parsed.exerciseNames, _pool)
        ..['Zercher Carry Esquisito'] = ImportChoice.own(
          'Zercher Carry Esquisito',
          muscleGroup: 'Pernas',
        );
      final plan = buildImport(parsed, c, userId: 'u', history: const []);
      final pernas = plan.toSave[1];
      expect(pernas.notes, 'Sábado cedo');
      final farmer = pernas.exercises.firstWhere(
        (e) => e.exerciseId == 'farmer_walk',
      );
      expect(farmer.sets.single.distanceMeters, 40);
      expect(plan.toSave.first.exercises.first.sets[1].rpe, 8);

      final back = Workout.fromMap(pernas.id, pernas.toMap());
      expect(back.notes, 'Sábado cedo');
      final set = back.exercises
          .firstWhere((e) => e.exerciseId == 'farmer_walk')
          .sets
          .single;
      expect(set.distanceMeters, 40);
      expect(set.notes, 'Pegada firme');

      // Série comum continua sem os campos novos no Firestore.
      final plain = WorkoutSet(reps: 8, weightKg: 40).toMap();
      expect(plain.containsKey('rpe'), isFalse);
      expect(plain.containsKey('notes'), isFalse);
      expect(plain.containsKey('distanceMeters'), isFalse);
    });
  });
}
