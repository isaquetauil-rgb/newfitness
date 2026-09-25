import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/admin/presentation/admin_users_screen.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Troca de papel no painel admin: passa pela Cloud Function `setUserRole`,
/// mostra carregando, mostra o erro real, só mostra sucesso quando a
/// Function confirma, e a lista reflete o papel novo.
void main() {
  late MockFirestoreService firestoreService;
  late MockFunctionsClient functionsClient;
  late StreamController<List<UserProfile>> users;
  late AdminProvider provider;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    functionsClient = MockFunctionsClient();
    users = StreamController<List<UserProfile>>.broadcast();
    when(() => firestoreService.watchAllUsers())
        .thenAnswer((_) => users.stream);
    provider = AdminProvider(
      firestoreService: firestoreService,
      functionsClient: functionsClient,
    );
  });

  tearDown(() => users.close());

  Future<void> pumpScreen(WidgetTester tester, List<UserProfile> list) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AdminProvider>.value(
          value: provider,
          child: const AdminUsersScreen(),
        ),
      ),
    );
    users.add(list);
    await tester.pump();
    await tester.pump();
  }

  Future<void> chooseRole(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pump();
  }

  const ana = UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com');
  const prof = UserProfile(
    uid: 'p1',
    name: 'Prof',
    email: 'p@x.com',
    role: UserRole.instructor,
  );

  testWidgets('mostra carregando e, no sucesso, a mensagem e o papel novo', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    when(() => functionsClient.call('setUserRole', any()))
        .thenAnswer((_) => pending.future);

    await pumpScreen(tester, [ana]);
    await chooseRole(tester, 'Instrutor');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(
      () => functionsClient.call('setUserRole', {
        'uid': 'u1',
        'role': 'instructor',
      }),
    ).called(1);

    pending.complete({'ok': true, 'revokedStudents': 0});
    users.add([
      const UserProfile(
        uid: 'u1',
        name: 'Ana',
        email: 'ana@x.com',
        role: UserRole.instructor,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Ana agora é Instrutor.'), findsOneWidget);
    expect(find.text('ana@x.com · Instrutor'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('erro da Function aparece e não há mensagem de sucesso', (
    tester,
  ) async {
    when(() => functionsClient.call('setUserRole', any())).thenThrow(
      const UnknownException('O papel NÃO foi alterado — tente de novo.'),
    );

    await pumpScreen(tester, [ana]);
    await chooseRole(tester, 'Nutricionista');
    await tester.pumpAndSettle();

    expect(
      find.text('O papel NÃO foi alterado — tente de novo.'),
      findsOneWidget,
    );
    expect(find.textContaining('agora é'), findsNothing);
    expect(find.text('ana@x.com · Aluno'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('rebaixar instrutor pede confirmação e informa desvinculados', (
    tester,
  ) async {
    when(() => functionsClient.call('setUserRole', any()))
        .thenAnswer((_) async => {'ok': true, 'revokedStudents': 2});

    await pumpScreen(tester, [prof]);
    await chooseRole(tester, 'Aluno');
    await tester.pumpAndSettle();

    // Cancelar não chama nada.
    expect(find.textContaining('serão desvinculados'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => functionsClient.call(any(), any()));

    await chooseRole(tester, 'Aluno');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    verify(
      () =>
          functionsClient.call('setUserRole', {'uid': 'p1', 'role': 'student'}),
    ).called(1);
    expect(
      find.text('Prof agora é Aluno · 2 aluno(s) desvinculado(s).'),
      findsOneWidget,
    );
  });
}
