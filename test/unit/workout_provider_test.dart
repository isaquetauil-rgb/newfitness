import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late WorkoutProvider provider;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = WorkoutProvider(firestoreService: firestoreService);
  });

  const exercise = Exercise(
    id: 'e1',
    name: 'Supino',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
  );

  test('startWorkout cria um treino ativo vazio', () {
    provider.startWorkout('u1');

    expect(provider.hasActiveWorkout, isTrue);
    expect(provider.activeWorkout!.userId, 'u1');
    expect(provider.activeWorkout!.exercises, isEmpty);
  });

  test('addExercise adiciona um exercício com uma série padrão', () {
    provider.startWorkout('u1');
    provider.addExercise(exercise);

    expect(provider.activeWorkout!.exercises, hasLength(1));
    expect(provider.activeWorkout!.exercises.first.sets, hasLength(1));
  });

  test('cancelWorkout limpa o treino ativo', () {
    provider.startWorkout('u1');
    provider.cancelWorkout();

    expect(provider.hasActiveWorkout, isFalse);
  });

  test('finishWorkout salva no Firestore e limpa o treino ativo', () async {
    when(() => firestoreService.saveWorkout(any()))
        .thenAnswer((_) async => 'w1');
    provider.startWorkout('u1');
    provider.addExercise(exercise);

    final ok = await provider.finishWorkout();

    expect(ok, isTrue);
    expect(provider.hasActiveWorkout, isFalse);
    verify(() => firestoreService.saveWorkout(any())).called(1);
  });

  test('finishWorkout retorna false se salvar falhar', () async {
    when(() => firestoreService.saveWorkout(any()))
        .thenThrow(Exception('offline'));
    provider.startWorkout('u1');

    final ok = await provider.finishWorkout();

    expect(ok, isFalse);
  });
}
