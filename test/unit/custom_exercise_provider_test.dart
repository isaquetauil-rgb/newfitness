import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late MockStorageService storageService;
  late CustomExerciseProvider provider;

  setUpAll(() {
    registerFallbackValue(
      const Exercise(
        id: '',
        name: '',
        muscleGroup: '',
        equipment: '',
        description: '',
        videoUrl: '',
      ),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    storageService = MockStorageService();
    provider = CustomExerciseProvider(
      firestoreService: firestoreService,
      storageService: storageService,
    );
  });

  const exercise = Exercise(
    id: 'e1',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: 'Deitado no banco...',
    videoUrl: 'https://youtube.com/watch?v=abc',
  );

  test('watchExercises delega ao FirestoreService', () async {
    final controller = StreamController<List<Exercise>>();
    when(() => firestoreService.watchCustomExercises('instructor1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchExercises('instructor1').first;
    controller.add([exercise]);
    final result = await future;

    expect(result, [exercise]);
    await controller.close();
  });

  test('saveExercise delega ao FirestoreService', () async {
    when(() => firestoreService.saveCustomExercise('instructor1', any()))
        .thenAnswer((_) async {});

    await provider.saveExercise('instructor1', exercise);

    verify(() => firestoreService.saveCustomExercise('instructor1', exercise))
        .called(1);
  });

  test('deleteExercise delega ao FirestoreService', () async {
    when(() => firestoreService.deleteCustomExercise('instructor1', 'e1'))
        .thenAnswer((_) async {});

    await provider.deleteExercise('instructor1', 'e1');

    verify(() => firestoreService.deleteCustomExercise('instructor1', 'e1'))
        .called(1);
  });

  test('uploadVideo liga e desliga isUploadingVideo e devolve a URL', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(
      () => storageService.uploadExerciseVideo(
        'instructor1',
        bytes,
        extension: 'mov',
      ),
    ).thenAnswer((_) async => 'https://storage.example/video.mov');

    expect(provider.isUploadingVideo, isFalse);
    final future = provider.uploadVideo('instructor1', bytes, extension: 'mov');
    expect(provider.isUploadingVideo, isTrue);

    final url = await future;

    expect(url, 'https://storage.example/video.mov');
    expect(provider.isUploadingVideo, isFalse);
  });
}
