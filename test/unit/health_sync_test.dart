import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/integrations/logic/health_sync.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Health Connect / Apple Saúde de mentira: registra o que o app pediu.
class FakeHealthGateway implements HealthGateway {
  HealthAvailability status = HealthAvailability.available;
  bool grant = true;
  bool fail = false;
  int installs = 0;
  final workouts = <({DateTime start, DateTime end, String title})>[];
  final weightsWritten = <WeightSample>[];
  List<WeightSample> weightsStored = [];

  @override
  Future<HealthAvailability> availability() async => status;

  @override
  Future<void> installProvider() async => installs++;

  @override
  Future<bool> requestAccess() async => grant;

  @override
  Future<bool> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async {
    if (fail) throw StateError('falhou');
    workouts.add((start: start, end: end, title: title));
    return true;
  }

  @override
  Future<bool> writeWeight(double kg, DateTime at) async {
    if (fail) throw StateError('falhou');
    weightsWritten.add(WeightSample(kg, at));
    return true;
  }

  @override
  Future<List<WeightSample>> readWeights(DateTime from, DateTime to) async {
    if (fail) throw StateError('falhou');
    return weightsStored;
  }
}

Workout _workout({
  int seconds = 3600,
  String? importedFrom,
  bool sets = true,
}) => Workout(
  id: 'w',
  userId: 'u',
  date: DateTime(2026, 11, 20, 18),
  name: 'Treino A',
  durationSeconds: seconds,
  importedFrom: importedFrom,
  exercises: [
    LoggedExercise(
      exerciseId: 'bench_press',
      exerciseName: 'Supino reto',
      sets: sets ? [WorkoutSet(reps: 8, weightKg: 60, completed: true)] : [],
    ),
  ],
);

void main() {
  late FakeHealthGateway gateway;
  late HealthSync sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeHealthGateway();
    sync = HealthSync(
      gateway: gateway,
      prefs: LocalPrefs(await SharedPreferences.getInstance()),
    );
  });

  test('desligado por padrão: não envia nada', () async {
    expect(sync.enabled, isFalse);
    expect(await sync.onWorkoutFinished(_workout()), isFalse);
    expect(await sync.pushWeight(70), isFalse);
    expect(await sync.readLatestWeight(), isNull);
    expect(gateway.workouts, isEmpty);
    expect(gateway.weightsWritten, isEmpty);
  });

  group('ligar', () {
    test('com permissão: liga e lembra', () async {
      expect(await sync.enable(), HealthEnableResult.enabled);
      expect(sync.enabled, isTrue);
    });

    test('permissão negada: continua desligado', () async {
      gateway.grant = false;
      expect(await sync.enable(), HealthEnableResult.denied);
      expect(sync.enabled, isFalse);
    });

    test('sem Health Connect instalado ou sem suporte', () async {
      gateway.status = HealthAvailability.needsInstall;
      expect(await sync.enable(), HealthEnableResult.needsInstall);
      gateway.status = HealthAvailability.unsupported;
      expect(await sync.enable(), HealthEnableResult.unsupported);
      expect(sync.enabled, isFalse);
    });

    test('desligar', () async {
      await sync.enable();
      await sync.disable();
      expect(sync.enabled, isFalse);
    });
  });

  group('treinos', () {
    setUp(() => sync.enable());

    test('envia com início, fim e nome', () async {
      expect(await sync.onWorkoutFinished(_workout()), isTrue);
      final w = gateway.workouts.single;
      expect(w.start, DateTime(2026, 11, 20, 18));
      expect(w.end, DateTime(2026, 11, 20, 19));
      expect(w.title, 'Treino A');
    });

    test('sem duração: 1 minuto', () async {
      await sync.onWorkoutFinished(_workout(seconds: 0));
      final w = gateway.workouts.single;
      expect(w.end.difference(w.start), const Duration(minutes: 1));
    });

    test('importado ou sem séries não vai', () async {
      expect(
        await sync.onWorkoutFinished(_workout(importedFrom: 'hevy')),
        isFalse,
      );
      expect(await sync.onWorkoutFinished(_workout(sets: false)), isFalse);
      expect(gateway.workouts, isEmpty);
    });

    test('falha do Saúde não derruba o app', () async {
      gateway.fail = true;
      expect(await sync.onWorkoutFinished(_workout()), isFalse);
      expect(await sync.pushWeight(70), isFalse);
      expect(await sync.readLatestWeight(), isNull);
    });
  });

  group('peso', () {
    setUp(() => sync.enable());

    test('grava o peso', () async {
      expect(await sync.pushWeight(72.5, at: DateTime(2026, 11, 20)), isTrue);
      expect(gateway.weightsWritten.single.kg, 72.5);
      expect(await sync.pushWeight(0), isFalse);
    });

    test('lê o mais recente', () async {
      gateway.weightsStored = [
        WeightSample(71, DateTime(2026, 11, 1)),
        WeightSample(72.4, DateTime(2026, 11, 15)),
        WeightSample(70, DateTime(2026, 10, 1)),
      ];
      final latest = await sync.readLatestWeight();
      expect(latest!.kg, 72.4);
      expect(latest.at, DateTime(2026, 11, 15));
    });

    test('weightDiffers', () {
      expect(weightDiffers(null, 70), isTrue);
      expect(weightDiffers(70, 70.02), isFalse);
      expect(weightDiffers(70, 70.5), isTrue);
    });

    test('latestWeight ignora valores inválidos', () {
      expect(latestWeight(const []), isNull);
      expect(
        latestWeight([
          WeightSample(0, DateTime(2026, 12)),
          WeightSample(70, DateTime(2026)),
        ])!.kg,
        70,
      );
    });
  });
}
