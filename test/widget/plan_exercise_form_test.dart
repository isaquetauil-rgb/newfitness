import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/instructor/logic/plan_template_provider.dart';
import 'package:newfitness/features/instructor/presentation/plan_editor_screen.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/shared/models/training_plan.dart';

import '../helpers/mocks.dart';

/// Formulário de exercício do plano: valores inválidos de séries/descanso
/// NÃO são salvos nem corrigidos — o formulário fica aberto com o erro.
void main() {
  late MockFirestoreService firestoreService;

  setUp(() => firestoreService = MockFirestoreService());

  Future<void> openExerciseForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                TrainingPlanProvider(firestoreService: firestoreService),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                PlanTemplateProvider(firestoreService: firestoreService),
          ),
        ],
        child: MaterialApp(
          home: PlanEditorScreen(
            args: PlanEditorArgs(
              studentUid: 'u1',
              studentName: 'Ana',
              instructorUid: 'i1',
              existingPlan: TrainingPlan(
                id: 'p1',
                studentUid: 'u1',
                instructorUid: 'i1',
                title: 'Plano',
                createdAt: DateTime(2024),
                workouts: const [
                  TrainingSubWorkout(
                    label: 'Treino A',
                    exercises: [
                      PlanExercise(
                        exerciseId: 'supino',
                        exerciseName: 'Supino',
                        targetSets: 4,
                        targetReps: '10',
                        restSeconds: 90,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supino'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);
  final confirm = find.text('Adicionar ao plano');

  Future<void> setValues(WidgetTester tester, String sets, String rest) async {
    await tester.enterText(field('Séries'), sets);
    await tester.enterText(field('Descanso (s)'), rest);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }

  for (final invalid in ['0', '-1', '21', '']) {
    testWidgets('séries "$invalid": não salva, mostra erro, mantém aberto', (
      tester,
    ) async {
      await openExerciseForm(tester);
      await setValues(tester, invalid, '60');

      expect(confirm, findsOneWidget); // formulário continua aberto
      expect(
        find.textContaining(RegExp('Entre 1 e 20|número inteiro')),
        findsOneWidget,
      );
      // nada foi "corrigido" no campo
      expect(
        tester.widget<TextField>(field('Séries')).controller!.text,
        invalid,
      );
    });
  }

  testWidgets('descanso -1: não salva e mostra erro', (tester) async {
    await openExerciseForm(tester);
    await setValues(tester, '3', '-1');

    expect(confirm, findsOneWidget);
    expect(find.text('Não pode ser negativo.'), findsOneWidget);
  });

  testWidgets('valores válidos (1 série, descanso 0) salvam e fecham', (
    tester,
  ) async {
    await openExerciseForm(tester);
    await setValues(tester, '1', '0');

    expect(confirm, findsNothing);
    expect(find.textContaining('1x10'), findsOneWidget);
    expect(find.textContaining('0s descanso'), findsOneWidget);
  });

  testWidgets('20 séries é válido', (tester) async {
    await openExerciseForm(tester);
    await setValues(tester, '20', '90');

    expect(confirm, findsNothing);
    expect(find.textContaining('20x10'), findsOneWidget);
  });
}
