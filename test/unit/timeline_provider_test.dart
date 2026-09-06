import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/timeline/logic/timeline_provider.dart';
import 'package:newfitness/shared/models/announcement.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late TimelineProvider provider;

  setUpAll(() {
    registerFallbackValue(
      Announcement(
        id: '',
        authorName: '',
        title: '',
        body: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = TimelineProvider(firestoreService: firestoreService);
  });

  final post = Announcement(
    id: 'p1',
    authorName: 'Admin',
    title: 'Bem-vindo',
    body: 'Primeiro aviso do mural.',
    createdAt: DateTime(2024, 1, 1),
    likeUids: const ['u2'],
  );

  test('watchAnnouncements delega ao FirestoreService', () async {
    final controller = StreamController<List<Announcement>>();
    when(() => firestoreService.watchAnnouncements())
        .thenAnswer((_) => controller.stream);

    final future = provider.watchAnnouncements().first;
    controller.add([post]);
    final result = await future;

    expect(result, [post]);
    await controller.close();
  });

  test('createAnnouncement monta o Announcement e delega', () async {
    when(() => firestoreService.createAnnouncement(any()))
        .thenAnswer((_) async {});

    await provider.createAnnouncement(
      authorName: 'Admin',
      title: 'Título',
      body: 'Corpo',
    );

    final saved =
        verify(() => firestoreService.createAnnouncement(captureAny()))
                .captured
                .single
            as Announcement;
    expect(saved.authorName, 'Admin');
    expect(saved.title, 'Título');
    expect(saved.body, 'Corpo');
  });

  test('toggleLike curte quando o usuário ainda não curtiu', () async {
    when(() => firestoreService.toggleAnnouncementLike('p1', 'u1', true))
        .thenAnswer((_) async {});

    await provider.toggleLike(post, 'u1');

    verify(() => firestoreService.toggleAnnouncementLike('p1', 'u1', true))
        .called(1);
  });

  test('toggleLike descurte quando o usuário já tinha curtido', () async {
    when(() => firestoreService.toggleAnnouncementLike('p1', 'u2', false))
        .thenAnswer((_) async {});

    await provider.toggleLike(post, 'u2');

    verify(() => firestoreService.toggleAnnouncementLike('p1', 'u2', false))
        .called(1);
  });

  test('deleteAnnouncement delega ao FirestoreService', () async {
    when(() => firestoreService.deleteAnnouncement('p1'))
        .thenAnswer((_) async {});

    await provider.deleteAnnouncement('p1');

    verify(() => firestoreService.deleteAnnouncement('p1')).called(1);
  });
}
