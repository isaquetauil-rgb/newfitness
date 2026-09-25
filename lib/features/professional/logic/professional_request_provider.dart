import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/core/network/functions_client.dart';
import 'package:newfitness/features/professional/logic/professional_request_validation.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Pedido para virar personal/nutricionista — lado do aluno (criar,
/// acompanhar, desistir/pedir de novo) e do admin (listar pendentes,
/// aprovar, recusar com motivo pela Cloud Function
/// `reviewProfessionalRequest`).
class ProfessionalRequestProvider extends ChangeNotifier {
  ProfessionalRequestProvider({
    FirestoreService? firestoreService,
    FunctionsClient? functionsClient,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _functionsClientOverride = functionsClient;

  final FirestoreService _firestoreService;

  // Criado só quando o admin decide um pedido (mesmo motivo de
  // `AuthProvider`: `FunctionsClient()` exige o Firebase inicializado).
  final FunctionsClient? _functionsClientOverride;
  FunctionsClient? _lazyFunctionsClient;
  FunctionsClient get _functionsClient =>
      _functionsClientOverride ?? (_lazyFunctionsClient ??= FunctionsClient());

  Stream<ProfessionalRequest?> watchMine(String uid) =>
      _firestoreService.watchProfessionalRequest(uid);

  Stream<List<ProfessionalRequest>> watchPending() =>
      _firestoreService.watchPendingProfessionalRequests();

  /// Cria o pedido pendente. `name` vem do perfil e `email` da conta
  /// logada — as regras recusam qualquer outro valor. Lança
  /// [ValidationException] se o registro/região forem inválidos.
  Future<void> submit({
    required UserProfile profile,
    required String accountEmail,
    required UserRole kind,
    required String registrationNumber,
    required String? registrationRegion,
  }) async {
    if (kind != UserRole.instructor && kind != UserRole.nutritionist) {
      throw const ValidationException('Escolha personal ou nutricionista.');
    }
    final numberError = validateRegistrationNumber(registrationNumber);
    if (numberError != null) throw ValidationException(numberError);
    final regionError = validateRegistrationRegion(kind, registrationRegion);
    if (regionError != null) throw ValidationException(regionError);

    await _firestoreService.createProfessionalRequest(
      uid: profile.uid,
      kind: userRoleToString(kind),
      registrationNumber: registrationNumber.trim(),
      registrationRegion: registrationRegion!,
      name: profile.name,
      email: accountEmail,
    );
  }

  /// Apaga o pedido do próprio usuário — desistir de um pendente, ou
  /// liberar um novo pedido depois de recusado (o histórico fica no
  /// servidor).
  Future<void> withdraw(String uid) =>
      _firestoreService.deleteProfessionalRequest(uid);

  Future<void> approve(String uid) => _functionsClient.call(
    'reviewProfessionalRequest',
    {'uid': uid, 'decision': 'approve'},
  );

  Future<void> reject(String uid, String reason) async {
    final error = validateRejectionReason(reason);
    if (error != null) throw ValidationException(error);
    await _functionsClient.call('reviewProfessionalRequest', {
      'uid': uid,
      'decision': 'reject',
      'reason': reason.trim(),
    });
  }
}
