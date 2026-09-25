import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/professional/logic/professional_request_provider.dart';
import 'package:newfitness/features/professional/logic/professional_request_validation.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Pedido para virar personal/nutricionista: validação (a mesma das regras
/// do Firestore), criação pelo aluno e decisão do admin pela Function.
void main() {
  setUpAll(registerTestFallbackValues);

  group('validação do registro (igual às regras)', () {
    test('número: 4 a 30, trim, só letras/números/./-/espaço', () {
      expect(validateRegistrationNumber('123456-G'), isNull);
      expect(validateRegistrationNumber('  CREF 123.456-G/SP  '), isNull);
      expect(validateRegistrationNumber('A1.2'), isNull);
      expect(validateRegistrationNumber('A' * 30), isNull);
      expect(validateRegistrationNumber(''), isNotNull);
      expect(validateRegistrationNumber('123'), isNotNull);
      expect(validateRegistrationNumber('A' * 31), isNotNull);
      expect(validateRegistrationNumber('1234#5'), isNotNull);
    });

    test('região: UF válida para CREF; 1 a 11 para CRN', () {
      expect(validateRegistrationRegion(UserRole.instructor, 'SP'), isNull);
      expect(validateRegistrationRegion(UserRole.instructor, 'XX'), isNotNull);
      expect(validateRegistrationRegion(UserRole.instructor, '3'), isNotNull);
      expect(validateRegistrationRegion(UserRole.instructor, null), isNotNull);
      expect(validateRegistrationRegion(UserRole.nutritionist, '1'), isNull);
      expect(validateRegistrationRegion(UserRole.nutritionist, '11'), isNull);
      expect(
        validateRegistrationRegion(UserRole.nutritionist, '12'),
        isNotNull,
      );
      expect(
        validateRegistrationRegion(UserRole.nutritionist, 'SP'),
        isNotNull,
      );
      expect(brazilianUfs, hasLength(27));
      expect(crnRegions, hasLength(11));
    });

    test('motivo da recusa: obrigatório, 1 a 500 (trim)', () {
      expect(validateRejectionReason('CREF inválido'), isNull);
      expect(validateRejectionReason('x' * 500), isNull);
      expect(validateRejectionReason(''), isNotNull);
      expect(validateRejectionReason('   '), isNotNull);
      expect(validateRejectionReason('x' * 501), isNotNull);
    });
  });

  test('modelo: lê status/datas e monta o rótulo do registro', () {
    final r = ProfessionalRequest.fromMap('u1', {
      'kind': 'nutritionist',
      'registrationNumber': '12345',
      'registrationRegion': '3',
      'name': 'Ana',
      'email': 'a@x.com',
      'status': 'rejected',
      'createdAt': DateTime(2026, 9, 1),
      'rejectionReason': 'CRN não encontrado',
    });
    expect(r.kind, UserRole.nutritionist);
    expect(r.status, ProfessionalRequestStatus.rejected);
    expect(r.registrationLabel, 'CRN-3 12345');
    expect(r.rejectionReason, 'CRN não encontrado');
    final cref = ProfessionalRequest.fromMap('u2', {
      'kind': 'instructor',
      'registrationNumber': '123456-G',
      'registrationRegion': 'SP',
      'status': 'pending',
    });
    expect(cref.registrationLabel, 'CREF 123456-G/SP');
  });

  group('ProfessionalRequestProvider', () {
    late MockFirestoreService firestoreService;
    late MockFunctionsClient functionsClient;
    late ProfessionalRequestProvider provider;
    const ana = UserProfile(
      uid: 'u1',
      name: 'Ana Souza',
      email: 'perfil@x.com',
    );

    setUp(() {
      firestoreService = MockFirestoreService();
      functionsClient = MockFunctionsClient();
      provider = ProfessionalRequestProvider(
        firestoreService: firestoreService,
        functionsClient: functionsClient,
      );
      when(
        () => firestoreService.createProfessionalRequest(
          uid: any(named: 'uid'),
          kind: any(named: 'kind'),
          registrationNumber: any(named: 'registrationNumber'),
          registrationRegion: any(named: 'registrationRegion'),
          name: any(named: 'name'),
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async {});
      when(() => functionsClient.call(any(), any()))
          .thenAnswer((_) async => {});
    });

    test('submit: nome do perfil, e-mail da conta, número com trim', () async {
      await provider.submit(
        profile: ana,
        accountEmail: 'conta@x.com',
        kind: UserRole.instructor,
        registrationNumber: '  123456-G ',
        registrationRegion: 'SP',
      );
      verify(
        () => firestoreService.createProfessionalRequest(
          uid: 'u1',
          kind: 'instructor',
          registrationNumber: '123456-G',
          registrationRegion: 'SP',
          name: 'Ana Souza',
          email: 'conta@x.com',
        ),
      ).called(1);
    });

    test('submit inválido não grava nada', () async {
      for (final call in <Future<void> Function()>[
        () => provider.submit(
          profile: ana,
          accountEmail: 'a@x.com',
          kind: UserRole.instructor,
          registrationNumber: '12',
          registrationRegion: 'SP',
        ),
        () => provider.submit(
          profile: ana,
          accountEmail: 'a@x.com',
          kind: UserRole.nutritionist,
          registrationNumber: '12345',
          registrationRegion: 'SP',
        ),
        () => provider.submit(
          profile: ana,
          accountEmail: 'a@x.com',
          kind: UserRole.student,
          registrationNumber: '12345',
          registrationRegion: '3',
        ),
      ]) {
        await expectLater(call(), throwsA(isA<ValidationException>()));
      }
      verifyNever(
        () => firestoreService.createProfessionalRequest(
          uid: any(named: 'uid'),
          kind: any(named: 'kind'),
          registrationNumber: any(named: 'registrationNumber'),
          registrationRegion: any(named: 'registrationRegion'),
          name: any(named: 'name'),
          email: any(named: 'email'),
        ),
      );
    });

    test('approve e reject chamam a Function com a decisão', () async {
      await provider.approve('u1');
      verify(
        () => functionsClient.call('reviewProfessionalRequest', {
          'uid': 'u1',
          'decision': 'approve',
        }),
      ).called(1);

      await provider.reject('u1', '  CREF não encontrado ');
      verify(
        () => functionsClient.call('reviewProfessionalRequest', {
          'uid': 'u1',
          'decision': 'reject',
          'reason': 'CREF não encontrado',
        }),
      ).called(1);
    });

    test('reject sem motivo não chama a Function', () async {
      await expectLater(
        provider.reject('u1', '   '),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => functionsClient.call(any(), any()));
    });

    test('withdraw apaga o pedido do próprio usuário', () async {
      when(() => firestoreService.deleteProfessionalRequest('u1'))
          .thenAnswer((_) async {});
      await provider.withdraw('u1');
      verify(() => firestoreService.deleteProfessionalRequest('u1')).called(1);
    });

    test('watchMine/watchPending delegam ao serviço', () async {
      final mine = StreamController<ProfessionalRequest?>();
      when(() => firestoreService.watchProfessionalRequest('u1'))
          .thenAnswer((_) => mine.stream);
      final future = provider.watchMine('u1').first;
      mine.add(null);
      expect(await future, isNull);
      await mine.close();

      when(() => firestoreService.watchPendingProfessionalRequests())
          .thenAnswer((_) => Stream.value(const []));
      expect(await provider.watchPending().first, isEmpty);
    });
  });
}
