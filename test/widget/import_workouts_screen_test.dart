import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/import/logic/workout_csv_parser.dart';
import 'package:newfitness/features/import/logic/workout_import.dart';
import 'package:newfitness/features/import/presentation/import_workouts_screen.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_functional_exercises.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestore;
  late MockAuthService authService;
  late StreamController<User?> authState;
  final saved = <Workout>[];

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(<Workout>[]);
  });

  setUp(() {
    saved.clear();
    firestore = MockFirestoreService();
    authService = MockAuthService();
    authState = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authState.stream);
    when(() => firestore.getUserProfile('u1')).thenAnswer(
      (_) async => const UserProfile(uid: 'u1', name: 'Ana', email: 'a@x.com'),
    );
    when(() => firestore.saveImportedWorkouts(any())).thenAnswer((inv) async {
      saved.addAll(inv.positionalArguments.first as List<Workout>);
    });
    when(() => firestore.recordImportedProgress(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() => authState.close());

  Future<void> pump(
    WidgetTester tester, {
    List<Workout> history = const [],
  }) async {
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('a@x.com');
    when(() => user.emailVerified).thenReturn(true);
    final auth = AuthProvider(
      authService: authService,
      firestoreService: firestore,
    );
    authState.add(user);
    await tester.pump();
    final csv = File('test/fixtures/import/hevy_exemplo.csv')
        .readAsStringSync();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => WorkoutProvider(firestoreService: firestore),
          ),
        ],
        child: MaterialApp(
          home: ImportWorkoutsScreen(
            pickCsv: () async => csv,
            pool: [...sampleExercises, ...sampleFunctionalExercises],
            history: history,
          ),
        ),
      ),
    );
  }

  testWidgets('prévia, escolher o que faltou e importar', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Escolher arquivo CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Arquivo do Hevy'), findsOneWidget);
    expect(find.textContaining('2 treinos'), findsOneWidget);
    expect(find.text('→ Supino reto'), findsOneWidget);
    expect(find.text('Exercícios · falta escolher 1'), findsOneWidget);
    // Sem escolher tudo, não deixa importar.
    await tester.scrollUntilVisible(
      find.text('Escolha os exercícios que faltam'),
      100,
    );
    expect(find.text('Escolha os exercícios que faltam'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Arquivo do Hevy'), -100);

    await tester.scrollUntilVisible(find.text('Zercher Carry Esquisito'), 100);
    await tester.tap(find.text('Zercher Carry Esquisito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar como exercício próprio'));
    await tester.pumpAndSettle();
    // Sem grupo muscular, "Criar" fica desligado.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Grupo muscular *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Costas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Exercício próprio: Zercher Carry Esquisito (Costas)'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Importar 2 treinos'), 100);
    await tester.tap(find.text('Importar 2 treinos'));
    await tester.pumpAndSettle();

    expect(find.text('2 treinos importados!'), findsOneWidget);
    expect(saved, hasLength(2));
    expect(saved[1].exercises.last.muscleGroup, 'Costas');
    expect(
      saved.every((w) => w.importedFrom == 'hevy' && w.userId == 'u1'),
      isTrue,
    );
    verify(() => firestore.recordImportedProgress('u1', any())).called(1);
  });

  testWidgets('reimportar: avisa e não tem nada novo', (tester) async {
    final csv = File('test/fixtures/import/hevy_exemplo.csv')
        .readAsStringSync();
    final parsed = parseWorkoutCsv(csv);
    final pool = [...sampleExercises, ...sampleFunctionalExercises];
    final choices = suggestChoices(parsed.exerciseNames, pool)
      ..['Zercher Carry Esquisito'] = ImportChoice.own(
        'Zercher',
        muscleGroup: 'Pernas',
      );
    final already = buildImport(
      parsed,
      choices,
      userId: 'u1',
      history: const [],
    ).toSave;

    await pump(tester, history: already);
    await tester.tap(find.text('Escolher arquivo CSV'));
    await tester.pumpAndSettle();
    // Ainda falta escolher um exercício: o resumo de duplicados só aparece
    // quando a importação está montada.
    expect(find.textContaining('2 já estavam no seu histórico'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Escolha os exercícios que faltam'),
      100,
    );
    await tester.tap(find.text('Zercher Carry Esquisito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar como exercício próprio'));
    await tester.pumpAndSettle();
    // Sem grupo muscular, "Criar" fica desligado.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Grupo muscular *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Costas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Nada novo para importar'), 100);
    expect(find.text('Nada novo para importar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('2 já estavam no seu histórico'),
      -100,
    );
    expect(
      find.textContaining('2 já estavam no seu histórico'),
      findsOneWidget,
    );
    expect(saved, isEmpty);
  });
}
