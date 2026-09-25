import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/network/functions_client.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Números gerais do app, mostrados no painel de administração.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.totalStudents,
    required this.totalInstructors,
    required this.totalNutritionists,
    required this.totalExercises,
    required this.totalWorkoutsLogged,
    required this.activeSubscriptions,
  });

  final int totalUsers;
  final int totalStudents;
  final int totalInstructors;
  final int totalNutritionists;
  final int totalExercises;
  final int totalWorkoutsLogged;
  final int activeSubscriptions;
}

/// Lógica do painel de administração — gerenciar usuários (promover/
/// rebaixar papel) e a biblioteca de exercícios compartilhada. Só o dono
/// do app acessa isto (ver [AuthProvider.isAdmin]); as regras do
/// Firestore são a barreira de segurança real.
class AdminProvider extends ChangeNotifier {
  AdminProvider({
    FirestoreService? firestoreService,
    FunctionsClient? functionsClient,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _functionsClientOverride = functionsClient;

  final FirestoreService _firestoreService;

  // Criado só quando o painel pede as estatísticas (mesmo motivo de
  // `AuthProvider`: `FunctionsClient()` exige o Firebase inicializado).
  final FunctionsClient? _functionsClientOverride;
  FunctionsClient? _lazyFunctionsClient;
  FunctionsClient get _functionsClient =>
      _functionsClientOverride ?? (_lazyFunctionsClient ??= FunctionsClient());

  Stream<List<UserProfile>> watchAllUsers() {
    return _firestoreService.watchAllUsers();
  }

  /// Promove um usuário a instrutor. O código de convite é emitido pela
  /// Cloud Function `ensureInviteCode` quando a pessoa abrir o app.
  Future<void> promoteToInstructor(UserProfile user) =>
      setRole(user, UserRole.instructor);

  /// Promove um usuário a nutricionista (papel isolado — ver
  /// `firestore.rules`).
  Future<void> promoteToNutritionist(UserProfile user) =>
      setRole(user, UserRole.nutritionist);

  /// Muda o papel pela Cloud Function `setUserRole` — o único caminho: as
  /// regras não deixam o cliente (nem o admin) gravar `role`. Ao tirar
  /// alguém de instrutor, a Function encerra antes todos os vínculos de
  /// instrutor dele (senão ele continuaria acessando os alunos antigos).
  /// Devolve quantos alunos foram desvinculados; lança o erro da Function
  /// se falhar (nesse caso o papel NÃO mudou).
  Future<int> setRole(UserProfile user, UserRole role) async {
    final result = await _functionsClient.call('setUserRole', {
      'uid': user.uid,
      'role': userRoleToString(role),
    });
    return (result['revokedStudents'] as num?)?.toInt() ?? 0;
  }

  /// Rebaixa um instrutor/nutricionista a aluno. De instrutor, os vínculos
  /// com os alunos são encerrados pela Function (histórico preservado).
  Future<void> demoteToStudent(UserProfile user) =>
      setRole(user, UserRole.student);

  Future<void> saveExercise(Exercise exercise) {
    return _firestoreService.seedExercise(exercise);
  }

  Future<void> deleteExercise(String id) {
    return _firestoreService.deleteExercise(id);
  }

  /// Estatísticas do painel, calculadas no servidor pela Cloud Function
  /// `getAdminStats` (só responde ao admin). Antes o app contava direto no
  /// Firestore, e as contagens de treinos/assinaturas de todos os alunos
  /// eram negadas pelas regras — o painel ficava carregando para sempre.
  /// Com [timeout] o painel nunca fica esperando indefinidamente.
  Future<AdminStats> loadStats({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final data = await _functionsClient
        .call('getAdminStats', {})
        .timeout(timeout);
    int read(String key) => (data[key] as num?)?.toInt() ?? 0;
    return AdminStats(
      totalUsers: read('totalUsers'),
      totalStudents: read('totalStudents'),
      totalInstructors: read('totalInstructors'),
      totalNutritionists: read('totalNutritionists'),
      totalExercises: read('totalExercises'),
      totalWorkoutsLogged: read('totalWorkoutsLogged'),
      activeSubscriptions: read('activeSubscriptions'),
    );
  }
}
