import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/nutrition/presentation/nutritionist_dashboard_screen.dart';
import 'package:newfitness/shared/models/meal_photo.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Painel da nutricionista: resumo, aviso de quem está sem plano alimentar
/// e situação de cada aluno pelas refeições registradas.
void main() {
  // Quarta-feira, 25/11/2026, 10h.
  final now = DateTime(2026, 11, 25, 10);
  late MockFirestoreService db;
  late MockAuthService authService;

  setUp(() {
    db = MockFirestoreService();
    authService = MockAuthService();
    when(() => db.watchNutritionStudents('n1')).thenAnswer(
      (_) => Stream.value([
        {'uid': 'ana', 'name': 'Ana Souza', 'email': 'ana@x.com'},
        {'uid': 'bia', 'name': 'Bia Lima', 'email': 'bia@x.com'},
      ]),
    );
    when(() => db.watchMealPhotos('ana')).thenAnswer(
      (_) => Stream.value([
        MealPhoto(
          id: 'm1',
          userId: 'ana',
          date: DateTime(2026, 11, 25, 8),
          mealType: MealType.breakfast,
          imageUrl: '',
        ),
      ]),
    );
    when(() => db.watchNutritionPlans('ana')).thenAnswer(
      (_) => Stream.value([
        NutritionPlan(
          id: 'p',
          studentUid: 'ana',
          nutritionistUid: 'n1',
          title: 'Plano',
          createdAt: DateTime(2026),
        ),
      ]),
    );
    when(() => db.watchMealPhotos('bia'))
        .thenAnswer((_) => Stream.value(const []));
    when(() => db.watchNutritionPlans('bia'))
        .thenAnswer((_) => Stream.value(const []));
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    const profile = UserProfile(
      uid: 'n1',
      name: 'Carla Nutri',
      email: 'n@x.com',
      role: UserRole.nutritionist,
      inviteCode: 'NUT987',
    );
    final user = MockUser();
    when(() => user.uid).thenReturn('n1');
    when(() => user.email).thenReturn('n@x.com');
    when(() => user.emailVerified).thenReturn(true);
    when(() => authService.authStateChanges)
        .thenAnswer((_) => Stream<User?>.value(user));
    when(() => db.getUserProfile('n1')).thenAnswer((_) async => profile);
    final auth = AuthProvider(authService: authService, firestoreService: db);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: NutritionistDashboardScreen(
            firestoreService: db,
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resumo, sem plano alimentar e situação pelas refeições', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Olá, Carla'), findsOneWidget);
    expect(find.text('NUT987'), findsOneWidget);
    expect(find.text('1 aluno sem plano alimentar'), findsOneWidget);
    expect(
      find.text('Registrou refeição hoje · 1 refeição na semana'),
      findsOneWidget,
    );
    expect(
      find.text('Ainda não registrou refeição · sem plano alimentar'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('no-plan-hint')));
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('Bia Lima'), findsOneWidget);
  });
}
