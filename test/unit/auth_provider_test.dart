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
  late MockFunctionsClient functionsClient;
  late StreamController<User?> authStateController;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    authService = MockAuthService();
    firestoreService = MockFirestoreService();
    functionsClient = MockFunctionsClient();
    authStateController = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() => authStateController.close());

  AuthProvider buildProvider() => AuthProvider(
    authService: authService,
    firestoreService: firestoreService,
  );

  // Usado pelos testes de vínculo aluno-instrutor/nutricionista — passa o
  // `functionsClient` mockado, já que `linkToInstructor`/`linkToNutritionist`
  // e `signUp` (com código) chamam a Cloud Function `linkToProfessional`.
  AuthProvider buildProviderWithFunctions() => AuthProvider(
    authService: authService,
    firestoreService: firestoreService,
    functionsClient: functionsClient,
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

  test(
    'cadastro cria UM perfil de aluno e não é duplicado pelo perfil padrão '
    '(authStateChanges chega antes de o perfil ser gravado)',
    () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => user.email).thenReturn('ana@x.com');
      when(() => user.displayName).thenReturn(null);
      final provider = buildProviderWithFunctions();

      // Firebase Auth avisa o login no meio do signUp, quando o documento
      // de perfil ainda não existe.
      when(
        () => authService.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async {
        authStateController.add(user);
        await Future<void>.delayed(Duration.zero);
        return user;
      });
      when(() => firestoreService.getUserProfile('u1'))
          .thenAnswer((_) async => null);
      when(() => firestoreService.createUserProfile(any()))
          .thenAnswer((_) async {});

      final ok = await provider.signUp('Ana', 'ana@x.com', '123456');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      final created = verify(
        () => firestoreService.createUserProfile(captureAny()),
      ).captured.cast<UserProfile>();
      // Só o perfil do cadastro foi gravado — nenhum perfil padrão extra.
      expect(created, hasLength(1));
      // O cadastro é sempre de aluno (personal/nutricionista pedem
      // aprovação depois) e não pede código de convite.
      expect(created.single.role, UserRole.student);
      expect(created.single.inviteCode, isNull);
      expect(provider.profile?.role, UserRole.student);
      verifyNever(() => functionsClient.call('ensureInviteCode', any()));
    },
  );

  test('instrutor com código antigo recebe o código confirmado pelo servidor '
      '(ex: o antigo tinha sido copiado por outra conta)', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('i1');
    when(() => firestoreService.getUserProfile('i1')).thenAnswer(
      (_) async => const UserProfile(
        uid: 'i1',
        name: 'Prof',
        email: 'p@x.com',
        role: UserRole.instructor,
        inviteCode: 'ANTIGO01',
      ),
    );
    when(() => functionsClient.call('ensureInviteCode', any()))
        .thenAnswer((_) async => {'code': 'NOVO2345'});

    final provider = buildProviderWithFunctions();
    authStateController.add(user);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => functionsClient.call('ensureInviteCode', any())).called(1);
    expect(provider.profile?.inviteCode, 'NOVO2345');
  });

  test('aluno NÃO chama ensureInviteCode', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('s1');
    when(() => firestoreService.getUserProfile('s1')).thenAnswer(
      (_) async => const UserProfile(uid: 's1', name: 'Ana', email: 'a@x.com'),
    );

    final provider = buildProviderWithFunctions();
    authStateController.add(user);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verifyNever(() => functionsClient.call(any(), any()));
    expect(provider.profile?.inviteCode, isNull);
  });

  group('desvincular profissional (Cloud Function)', () {
    test(
      'unlinkFromInstructor chama a Function e recarrega o perfil',
      () async {
        final user = MockUser();
        when(() => user.uid).thenReturn('s1');
        var linked = true;
        when(() => firestoreService.getUserProfile('s1')).thenAnswer(
          (_) async => UserProfile(
            uid: 's1',
            name: 'Ana',
            email: 'a@x.com',
            instructorId: linked ? 'i1' : null,
          ),
        );
        when(
          () => functionsClient.call('unlinkFromProfessional', {
            'kind': 'instructor',
          }),
        ).thenAnswer((_) async {
          linked = false;
          return {'ok': true};
        });

        final provider = buildProviderWithFunctions();
        authStateController.add(user);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(provider.profile?.instructorId, 'i1');

        final ok = await provider.unlinkFromInstructor();

        expect(ok, isTrue);
        expect(provider.profile?.instructorId, isNull);
        expect(provider.isLoading, isFalse);
        // Nunca escreve o vínculo direto no Firestore.
        verifyNever(() => firestoreService.updateUserProfile(any()));
      },
    );

    test(
      'falha ao desvincular mostra erro e não trava o carregamento',
      () async {
        when(() => functionsClient.call('unlinkFromProfessional', any()))
            .thenThrow(Exception('offline'));

        final provider = buildProviderWithFunctions();
        final ok = await provider.unlinkFromNutritionist();

        expect(ok, isFalse);
        expect(provider.errorMessage, isNotNull);
        expect(provider.isLoading, isFalse);
      },
    );
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

  group('vínculo aluno -> instrutor/nutricionista (segurança)', () {
    // Regressão do achado de segurança: um aluno não pode ganhar acesso de
    // instrutor escrevendo `instructorId` direto no próprio perfil — o
    // único caminho é a Cloud Function `linkToProfessional`, que valida um
    // código de convite real no servidor. Estes testes provam que o
    // `AuthProvider` nunca tenta a escrita insegura (mesmo que
    // `firestore.rules` já bloqueie isso, o cliente não deve nem tentar).

    test('signUp cria o perfil SEM instructorId/nutritionistId — só a Cloud '
        'Function pode preencher esses campos depois', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('student1');
      when(
        () => authService.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => user);
      when(() => firestoreService.createUserProfile(any()))
          .thenAnswer((_) async {});

      final provider = buildProviderWithFunctions();
      final ok = await provider.signUp('Ana', 'ana@x.com', '123456');

      expect(ok, isTrue);
      final captured = verify(
        () => firestoreService.createUserProfile(captureAny()),
      ).captured;
      final created = captured.single as UserProfile;
      expect(created.instructorId, isNull);
      expect(created.nutritionistId, isNull);
      verifyNever(() => functionsClient.call(any(), any()));
    });

    test('signUp com código de instrutor delega a validação e o vínculo à '
        'Cloud Function', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('student1');
      when(
        () => authService.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => user);
      when(() => firestoreService.createUserProfile(any()))
          .thenAnswer((_) async {});
      when(
        () => functionsClient.call('linkToProfessional', {
          'code': 'ABC123',
          'kind': 'instructor',
        }),
      ).thenAnswer((_) async => {'ok': true, 'name': 'Prof. João'});
      when(() => firestoreService.getUserProfile('student1')).thenAnswer(
        (_) async => const UserProfile(
          uid: 'student1',
          name: 'Ana',
          email: 'ana@x.com',
          instructorId: 'instructor1',
        ),
      );

      final provider = buildProviderWithFunctions();
      final ok = await provider.signUp(
        'Ana',
        'ana@x.com',
        '123456',
        instructorCode: 'ABC123',
      );

      expect(ok, isTrue);
      verify(
        () => functionsClient.call('linkToProfessional', {
          'code': 'ABC123',
          'kind': 'instructor',
        }),
      ).called(1);
      expect(provider.profile?.instructorId, 'instructor1');
    });

    test('um código de instrutor inválido não derruba o cadastro — só o '
        'vínculo fica pendente', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('student1');
      when(
        () => authService.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => user);
      when(() => firestoreService.createUserProfile(any()))
          .thenAnswer((_) async {});
      when(() => functionsClient.call('linkToProfessional', any()))
          .thenThrow(Exception('Código de instrutor inválido.'));

      final provider = buildProviderWithFunctions();
      final ok = await provider.signUp(
        'Ana',
        'ana@x.com',
        '123456',
        instructorCode: 'CODIGO-ERRADO',
      );

      expect(ok, isTrue);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.instructorId, isNull);
    });

    test('linkToInstructor chama a Cloud Function e nunca escreve '
        'instructorId direto no Firestore', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('student1');
      when(() => firestoreService.getUserProfile('student1')).thenAnswer(
        (_) async => const UserProfile(
          uid: 'student1',
          name: 'Ana',
          email: 'ana@x.com',
          instructorId: 'instructor1',
        ),
      );
      when(
        () => functionsClient.call('linkToProfessional', {
          'code': 'ABC123',
          'kind': 'instructor',
        }),
      ).thenAnswer((_) async => {'ok': true, 'name': 'Prof. João'});

      final provider = buildProviderWithFunctions();
      authStateController.add(user);
      await Future<void>.delayed(Duration.zero);

      final name = await provider.linkToInstructor('ABC123');

      expect(name, 'Prof. João');
      expect(provider.profile?.instructorId, 'instructor1');
      verify(
        () => functionsClient.call('linkToProfessional', {
          'code': 'ABC123',
          'kind': 'instructor',
        }),
      ).called(1);
      // O cliente nunca tenta gravar instructorId por conta própria —
      // toda a escrita fica a cargo da Cloud Function (Admin SDK).
      verifyNever(() => firestoreService.updateUserProfile(any()));
    });

    test('linkToInstructor com código inválido não altera o perfil e expõe '
        'uma mensagem de erro', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('student1');
      when(() => firestoreService.getUserProfile('student1')).thenAnswer(
        (_) async =>
            const UserProfile(uid: 'student1', name: 'Ana', email: 'ana@x.com'),
      );
      when(() => functionsClient.call('linkToProfessional', any()))
          .thenThrow(Exception('Código de instrutor inválido.'));

      final provider = buildProviderWithFunctions();
      authStateController.add(user);
      await Future<void>.delayed(Duration.zero);

      final name = await provider.linkToInstructor('CODIGO-ERRADO');

      expect(name, isNull);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => firestoreService.updateUserProfile(any()));
      verifyNever(() => firestoreService.createUserProfile(any()));
    });
  });
}
