import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAuthService authService;
  late MockFirestoreService firestoreService;
  late StreamController<User?> authStateController;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    authService = MockAuthService();
    firestoreService = MockFirestoreService();
    authStateController = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() => authStateController.close());

  AuthProvider buildProvider() => AuthProvider(
    authService: authService,
    firestoreService: firestoreService,
  );

  test(
    'signIn bem-sucedido carrega o perfil quando o auth state muda',
    () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      when(
        () => authService.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user);
      when(() => firestoreService.getUserProfile('u1')).thenAnswer(
        (_) async =>
            const UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com'),
      );

      final provider = buildProvider();
      final ok = await provider.signIn('ana@x.com', '123456');

      expect(ok, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);

      authStateController.add(user);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isLoggedIn, isTrue);
      expect(provider.profile?.name, 'Ana');
    },
  );

  test('quando o perfil não existe no Firestore, cria um perfil padrão automaticamente', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('ana@x.com');
    when(() => user.displayName).thenReturn('Ana Silva');
    when(() => firestoreService.getUserProfile('u1'))
        .thenAnswer((_) async => null);
    when(() => firestoreService.createUserProfile(any()))
        .thenAnswer((_) async {});

    final provider = buildProvider();
    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    expect(provider.profile, isNotNull);
    expect(provider.profile!.uid, 'u1');
    expect(provider.profile!.name, 'Ana Silva');
    expect(provider.profileError, isNull);
    verify(() => firestoreService.createUserProfile(any())).called(1);
  });

  test('signIn com credenciais inválidas expõe mensagem amigável', () async {
    when(
      () => authService.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(FirebaseAuthException(code: 'wrong-password'));
    when(() => authService.friendlyError(any()))
        .thenReturn('E-mail ou senha incorretos.');

    final provider = buildProvider();
    final ok = await provider.signIn('ana@x.com', 'errada');

    expect(ok, isFalse);
    expect(provider.errorMessage, 'E-mail ou senha incorretos.');
  });

  test('resetPassword chama o AuthService e retorna sucesso', () async {
    when(() => authService.sendPasswordResetEmail(any()))
        .thenAnswer((_) async {});

    final provider = buildProvider();
    final ok = await provider.resetPassword('ana@x.com');

    expect(ok, isTrue);
    verify(() => authService.sendPasswordResetEmail('ana@x.com')).called(1);
  });

  test('signOut delega ao AuthService', () async {
    when(() => authService.signOut()).thenAnswer((_) async {});
    final provider = buildProvider();

    await provider.signOut();

    verify(() => authService.signOut()).called(1);
  });

  test('isAdmin é true só para o e-mail do dono do app', () async {
    final owner = MockUser();
    when(() => owner.uid).thenReturn('owner-uid');
    when(() => owner.email).thenReturn('isaquetrabalho005@gmail.com');
    when(() => firestoreService.getUserProfile('owner-uid'))
        .thenAnswer((_) async => null);
    when(() => firestoreService.createUserProfile(any()))
        .thenAnswer((_) async {});

    final provider = buildProvider();
    authStateController.add(owner);
    await Future<void>.delayed(Duration.zero);

    expect(provider.isAdmin, isTrue);
  });

  test('isAdmin é false para qualquer outro usuário', () async {
    final other = MockUser();
    when(() => other.uid).thenReturn('u2');
    when(() => other.email).thenReturn('outra.pessoa@example.com');
    when(() => firestoreService.getUserProfile('u2'))
        .thenAnswer((_) async => null);
    when(() => firestoreService.createUserProfile(any()))
        .thenAnswer((_) async {});

    final provider = buildProvider();
    authStateController.add(other);
    await Future<void>.delayed(Duration.zero);

    expect(provider.isAdmin, isFalse);
  });
}
