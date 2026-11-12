import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/workout/presentation/plate_calculator_sheet.dart';

import '../helpers/mocks.dart';

void main() {
  late AuthProvider auth;

  setUp(() {
    final authService = MockAuthService();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    auth = AuthProvider(
      authService: authService,
      firestoreService: MockFirestoreService(),
    );
  });

  Future<List<double>> pump(WidgetTester tester, double kg) async {
    final used = <double>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: PlateCalculatorSheet(weightKg: kg, onUse: used.add),
          ),
        ),
      ),
    );
    return used;
  }

  testWidgets('100 kg na barra de 20: 25 + 15 de cada lado', (tester) async {
    await pump(tester, 100);
    expect(find.text('Anilhas para 100 kg'), findsOneWidget);
    expect(find.text('Barra de 20 kg'), findsOneWidget);
    expect(find.text('1 × 25 kg'), findsOneWidget);
    expect(find.text('1 × 15 kg'), findsOneWidget);
    expect(find.textContaining('não fecha'), findsNothing);
  });

  testWidgets('peso que não fecha: mostra o mais perto e deixa usar', (
    tester,
  ) async {
    final used = await pump(tester, 61);
    expect(find.textContaining('O mais perto é 60 kg'), findsOneWidget);
    await tester.tap(find.text('Usar 60 kg'));
    await tester.pumpAndSettle();
    expect(used, [60]);
  });

  testWidgets('abre a configuração da academia', (tester) async {
    await pump(tester, 50);
    await tester.tap(find.text('Barra e anilhas da minha academia'));
    await tester.pumpAndSettle();
    expect(find.text('Sua academia'), findsOneWidget);
    expect(find.byKey(const ValueKey('plate-option-25.0')), findsOneWidget);
  });
}
