import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/integrations/logic/health_sync.dart';
import 'package:newfitness/features/integrations/presentation/integrations_screen.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';
import '../unit/health_sync_test.dart' show FakeHealthGateway;

void main() {
  late MockFirestoreService firestore;
  late MockAuthService authService;
  late StreamController<User?> authState;
  late FakeHealthGateway gateway;
  late HealthSync sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeHealthGateway();
    sync = HealthSync(
      gateway: gateway,
      prefs: LocalPrefs(await SharedPreferences.getInstance()),
    );
    firestore = MockFirestoreService();
    authService = MockAuthService();
    authState = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authState.stream);
    when(() => firestore.getUserProfile('u1')).thenAnswer(
      (_) async => const UserProfile(
        uid: 'u1',
        name: 'Ana',
        email: 'a@x.com',
        weightKg: 70,
      ),
    );
    when(() => firestore.updateWeight(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() => authState.close());

  Future<void> pump(WidgetTester tester) async {
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
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(home: IntegrationsScreen(sync: sync)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desligado por padrão; ligar mostra o peso', (tester) async {
    await pump(tester);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(find.textContaining('Ver peso no'), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(sync.enabled, isTrue);
    expect(find.text('No seu perfil: 70 kg'), findsOneWidget);

    gateway.weightsStored = [WeightSample(72.4, DateTime(2026, 11, 15))];
    await tester.tap(find.textContaining('Ver peso no'));
    await tester.pumpAndSettle();
    expect(find.textContaining('72,4 kg em 15/11/2026'), findsOneWidget);

    await tester.tap(find.text('Usar este peso no meu perfil'));
    await tester.pumpAndSettle();
    verify(() => firestore.updateWeight('u1', 72.4)).called(1);

    await tester.tap(find.textContaining('Enviar 72,4 kg'));
    await tester.pumpAndSettle();
    expect(gateway.weightsWritten.single.kg, 72.4);
  });

  testWidgets('permissão negada: continua desligado e explica', (tester) async {
    gateway.grant = false;
    await pump(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(sync.enabled, isFalse);
    expect(find.textContaining('Sem permissão'), findsOneWidget);
  });

  testWidgets('sem Health Connect: oferece instalar', (tester) async {
    gateway.status = HealthAvailability.needsInstall;
    await pump(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Instalar o Health Connect'), findsOneWidget);
    await tester.tap(find.text('Abrir a loja'));
    await tester.pumpAndSettle();
    expect(gateway.installs, 1);
    expect(sync.enabled, isFalse);
  });
}
