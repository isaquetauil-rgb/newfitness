import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/workout/data/health_screening_service.dart';
import 'package:newfitness/features/workout/presentation/health_screening_sheet.dart';
import 'package:newfitness/shared/models/health_screening.dart';
import 'package:newfitness/shared/models/workout_templates.dart';

class _FakeService implements HealthScreeningService {
  _FakeService([this.stored]);

  HealthScreening? stored;
  final saved = <HealthScreening>[];

  @override
  Future<HealthScreening?> latest(String uid) async => stored;

  @override
  Future<void> save(String uid, HealthScreening screening) async {
    saved.add(screening);
    stored = screening;
  }

  @override
  Stream<HealthScreening?> watchLatest(String uid) => Stream.value(stored);
}

final _now = DateTime(2026, 11, 10);
List<bool> _all(bool v) => List.filled(healthScreeningQuestions.length, v);

void main() {
  group('HealthScreening', () {
    test('liberado só sem nenhum "sim"', () {
      final ok = HealthScreening(answers: _all(false), createdAt: 0);
      final flagged = HealthScreening(
        answers: [..._all(false)]..[2] = true,
        createdAt: 0,
      );
      expect(ok.cleared, isTrue);
      expect(flagged.cleared, isFalse);
      expect(flagged.flaggedQuestions, [healthScreeningQuestions[2]]);
    });

    test('vence depois de 180 dias ou se a versão mudar', () {
      final recent = HealthScreening(
        answers: _all(false),
        createdAt: _now
            .subtract(const Duration(days: 10))
            .millisecondsSinceEpoch,
      );
      final old = HealthScreening(
        answers: _all(false),
        createdAt: _now
            .subtract(const Duration(days: 200))
            .millisecondsSinceEpoch,
      );
      final otherVersion = HealthScreening(
        answers: _all(false),
        createdAt: _now.millisecondsSinceEpoch,
        version: 0,
      );
      expect(recent.isValidAt(_now), isTrue);
      expect(old.isValidAt(_now), isFalse);
      expect(otherVersion.isValidAt(_now), isFalse);
    });

    test('ida e volta pelo mapa', () {
      final s = HealthScreening(
        answers: [..._all(false)]..[0] = true,
        createdAt: 5,
      );
      final back = HealthScreening.fromMap('x', s.toMap());
      expect(s.toMap()['cleared'], isFalse);
      expect(back.answers, s.answers);
      expect(back.createdAt, 5);
      expect(back.version, healthScreeningVersion);
    });

    test('só os treinos da área de saúde pedem o questionário', () {
      final care = workoutTemplates
          .where((t) => t.needsHealthScreening)
          .map((t) => t.id)
          .toSet();
      expect(care, containsAll(['idosos', 'pouca_mobilidade', 'postura']));
      expect(care.contains('primeiros_passos'), isFalse);
      expect(care.contains('mma'), isFalse);
    });
  });

  group('ensureHealthClearance', () {
    Future<bool?> Function() pump(WidgetTester tester, _FakeService service) {
      bool? result;
      return () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await ensureHealthClearance(
                    context,
                    'aluno',
                    service: service,
                    now: () => _now,
                  ),
                  child: const Text('começar'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('começar'));
        await tester.pumpAndSettle();
        return result;
      };
    }

    Future<void> answerAll(
      WidgetTester tester,
      String label, {
      bool checkSendDisabled = false,
    }) async {
      final list = find.descendant(
        of: find.byType(HealthScreeningForm),
        matching: find.byType(Scrollable),
      );
      for (int i = 0; i < healthScreeningQuestions.length; i++) {
        final question = find.byKey(ValueKey('health-q$i'));
        await tester.scrollUntilVisible(question, 150, scrollable: list.first);
        await tester.tap(
          find.descendant(of: question, matching: find.text(label)),
        );
        await tester.pump();
      }
      final declare = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(declare, 150, scrollable: list.first);
      if (checkSendDisabled) {
        // Tudo respondido, mas sem a declaração: ainda não envia.
        final send = find.widgetWithText(FilledButton, 'Enviar respostas');
        await tester.scrollUntilVisible(send, 150, scrollable: list.first);
        expect(tester.widget<FilledButton>(send).onPressed, isNull);
      }
      await tester.tap(declare);
      await tester.pump();
    }

    testWidgets('resposta recente e liberada: começa sem perguntar', (
      tester,
    ) async {
      final service = _FakeService(
        HealthScreening(
          answers: _all(false),
          createdAt: _now.millisecondsSinceEpoch,
        ),
      );
      final run = pump(tester, service);
      expect(await run(), isTrue);
      expect(find.byType(HealthScreeningForm), findsNothing);
      expect(service.saved, isEmpty);
    });

    testWidgets('sem resposta: pergunta, grava e libera com tudo "não"', (
      tester,
    ) async {
      final service = _FakeService();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await ensureHealthClearance(
                  context,
                  'aluno',
                  service: service,
                  now: () => _now,
                ),
                child: const Text('começar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('começar'));
      await tester.pumpAndSettle();
      expect(find.byType(HealthScreeningForm), findsOneWidget);

      final send = find.widgetWithText(FilledButton, 'Enviar respostas');
      await answerAll(tester, 'Não', checkSendDisabled: true);
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(service.saved.single.cleared, isTrue);
      expect(result, isTrue);
    });

    testWidgets('com "sim": grava e mostra o aviso de acompanhamento', (
      tester,
    ) async {
      final service = _FakeService();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await ensureHealthClearance(
                  context,
                  'aluno',
                  service: service,
                  now: () => _now,
                ),
                child: const Text('começar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('começar'));
      await tester.pumpAndSettle();
      await answerAll(tester, 'Sim');
      final send = find.widgetWithText(FilledButton, 'Enviar respostas');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(service.saved.single.cleared, isFalse);
      expect(find.byType(HealthBlockedView), findsOneWidget);
      expect(
        find.text('Este treino precisa de acompanhamento'),
        findsOneWidget,
      );

      // Fechar o aviso não libera o treino.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
