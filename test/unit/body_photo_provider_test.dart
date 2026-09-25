import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/progress/logic/body_photo_provider.dart';
import 'package:newfitness/shared/models/body_photo.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late MockStorageService storageService;
  late BodyPhotoProvider provider;
  final now = DateTime(2024, 5, 1, 10);

  setUpAll(() {
    registerFallbackValue(BodyPhoto(id: '', userId: '', date: DateTime(2024)));
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    storageService = MockStorageService();
    provider = BodyPhotoProvider(
      firestoreService: firestoreService,
      storageService: storageService,
      clock: () => now,
    );
  });

  test(
    'addPhoto envia o arquivo e grava só o caminho privado (sem URL pública)',
    () async {
      when(() => storageService.uploadBodyPhoto('student1', any()))
          .thenAnswer((_) async => 'users/student1/body_photos/1.jpg');
      when(() => firestoreService.addBodyPhoto(any())).thenAnswer((_) async {});

      await provider.addPhoto(
        'student1',
        XFile.fromData(Uint8List.fromList([1, 2, 3])),
        position: PhotoPosition.leftSide,
        note: 'semana 4',
        date: DateTime(2024, 4, 30),
      );

      final saved =
          verify(() => firestoreService.addBodyPhoto(captureAny()))
                  .captured
                  .single
              as BodyPhoto;
      expect(saved.userId, 'student1');
      expect(saved.storagePath, 'users/student1/body_photos/1.jpg');
      expect(saved.imageUrl, isNull);
      expect(saved.position, PhotoPosition.leftSide);
      expect(saved.note, 'semana 4');
      expect(saved.date, DateTime(2024, 4, 30));
      expect(saved.uploadedByUid, 'student1');
      expect(saved.createdAt, now);
      expect(provider.isUploading, isFalse);
    },
  );

  test('loadBytes reaproveita o download na mesma sessão', () async {
    when(() => storageService.getBytes('p'))
        .thenAnswer((_) async => Uint8List.fromList([9]));

    await provider.loadBytes('p');
    await provider.loadBytes('p');

    verify(() => storageService.getBytes('p')).called(1);
  });

  test('deletePhoto remove arquivo pelo caminho e depois o registro', () async {
    when(() => storageService.deleteByPath(any())).thenAnswer((_) async {});
    when(() => firestoreService.deleteBodyPhoto('student1', 'ph1'))
        .thenAnswer((_) async {});

    await provider.deletePhoto(
      BodyPhoto(
        id: 'ph1',
        userId: 'student1',
        date: DateTime(2024),
        storagePath: 'users/student1/body_photos/1.jpg',
      ),
    );

    verify(
      () => storageService.deleteByPath('users/student1/body_photos/1.jpg'),
    ).called(1);
    verify(() => firestoreService.deleteBodyPhoto('student1', 'ph1')).called(1);
  });

  test('deletePhoto de foto antiga usa a URL', () async {
    when(() => storageService.deleteByUrl(any())).thenAnswer((_) async {});
    when(() => firestoreService.deleteBodyPhoto('student1', 'old'))
        .thenAnswer((_) async {});

    await provider.deletePhoto(
      BodyPhoto(
        id: 'old',
        userId: 'student1',
        date: DateTime(2024),
        imageUrl: 'https://x/y.jpg',
      ),
    );

    verify(() => storageService.deleteByUrl('https://x/y.jpg')).called(1);
    verifyNever(() => storageService.deleteByPath(any()));
  });
}
