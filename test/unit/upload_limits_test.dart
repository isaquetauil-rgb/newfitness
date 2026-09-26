import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/ai/logic/meal_photo_provider.dart';
import 'package:newfitness/shared/models/meal_photo.dart';
import 'package:newfitness/shared/services/storage_service.dart';
import 'package:newfitness/shared/services/upload_limits.dart';

import '../helpers/mocks.dart';

class _MockStorage extends Mock implements FirebaseStorage {}

class _MockReference extends Mock implements Reference {}

/// Rodada 5 — limites de upload (os mesmos de `storage.rules`) e mensagem
/// amigável quando o arquivo é recusado.
void main() {
  const mb = 1024 * 1024;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
  });

  group('limites conferidos antes do envio', () {
    test('vídeo: só MP4, MOV ou WebM, até 50 MB', () {
      expect(UploadLimits.exerciseVideoProblem('mp4', 50 * mb), isNull);
      expect(UploadLimits.exerciseVideoProblem('MOV', 10), isNull);
      expect(UploadLimits.exerciseVideoProblem('webm', 10), isNull);
      expect(
        UploadLimits.exerciseVideoProblem('mp4', 50 * mb + 1),
        'Vídeo maior que 50 MB. Grave um vídeo mais curto (até 20 s) ou em '
        '1080p.',
      );
      for (final ext in ['m4v', '3gp', 'mkv', 'avi']) {
        expect(
          UploadLimits.exerciseVideoProblem(ext, 10),
          'Formato não suportado. Use MP4, MOV ou WebM.',
        );
      }
      expect(
        UploadLimits.maxExerciseVideoDuration,
        const Duration(seconds: 20),
      );
    });

    test('foto de refeição: até 5 MB', () {
      expect(UploadLimits.mealPhotoProblem(5 * mb), isNull);
      expect(UploadLimits.mealPhotoProblem(5 * mb + 1), isNotNull);
    });

    test('foto de refeição grande é recusada antes de ler e enviar', () async {
      final storageService = MockStorageService();
      final provider = MealPhotoProvider(
        firestoreService: MockFirestoreService(),
        storageService: storageService,
        aiService: MockAiService(),
      );

      await expectLater(
        provider.addPhoto(
          'u1',
          XFile.fromData(Uint8List(5 * mb + 1)),
          MealType.lunch,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('JPEG, PNG ou WebP até 5 MB'),
          ),
        ),
      );
      verifyNever(() => storageService.uploadMealPhoto(any(), any()));
      expect(provider.isUploading, isFalse);
    });
  });

  group('upload recusado pelas regras do Storage', () {
    late _MockStorage storage;
    late _MockReference root;
    late _MockReference file;
    late StorageService service;

    setUp(() {
      storage = _MockStorage();
      root = _MockReference();
      file = _MockReference();
      when(() => storage.ref()).thenReturn(root);
      when(() => root.child(any())).thenReturn(file);
      when(() => file.putData(any(), any())).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
      );
      service = StorageService(storage: storage);
    });

    test('foto de refeição: mensagem com tipo e tamanho aceitos', () async {
      await expectLater(
        service.uploadMealPhoto('u1', Uint8List(10)),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Foto recusada. Envie uma imagem JPEG, PNG ou WebP até 5 MB.',
          ),
        ),
      );
    });

    test('vídeo: mensagem com formatos e limite', () async {
      await expectLater(
        service.uploadExerciseVideo('p1', Uint8List(10), extension: 'mov'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Vídeo recusado. Envie MP4, MOV ou WebM de até 50 MB (até 20 s).',
          ),
        ),
      );
      final metadata =
          verify(() => file.putData(any(), captureAny())).captured.single
              as SettableMetadata;
      expect(metadata.contentType, 'video/quicktime');
    });

    test('vídeo em formato não aceito nem chega ao Storage', () async {
      await expectLater(
        service.uploadExerciseVideo('p1', Uint8List(10), extension: 'mkv'),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => file.putData(any(), any()));
    });

    test('outras falhas continuam como erro de rede', () async {
      when(() => file.putData(any(), any())).thenThrow(
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'retry-limit-exceeded',
        ),
      );
      await expectLater(
        service.uploadMealPhoto('u1', Uint8List(10)),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
