import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Números gerais do app, mostrados no painel de administração.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.totalStudents,
    required this.totalInstructors,
    required this.totalExercises,
    required this.totalWorkoutsLogged,
  });

  final int totalUsers;
  final int totalStudents;
  final int totalInstructors;
  final int totalExercises;
  final int totalWorkoutsLogged;
}

/// Lógica do painel de administração — gerenciar usuários (promover/
/// rebaixar papel) e a biblioteca de exercícios compartilhada. Só o dono
/// do app acessa isto (ver [AuthProvider.isAdmin]); as regras do
/// Firestore são a barreira de segurança real.
class AdminProvider extends ChangeNotifier {
  AdminProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<UserProfile>> watchAllUsers() {
    return _firestoreService.watchAllUsers();
  }

  /// Promove um usuário a instrutor, gerando um código de convite se ele
  /// ainda não tiver um.
  Future<void> promoteToInstructor(UserProfile user) async {
    final inviteCode =
        user.inviteCode ?? await _firestoreService.generateUniqueInviteCode();
    await _firestoreService.updateUserProfile(
      user.copyWith(role: UserRole.instructor, inviteCode: inviteCode),
    );
  }

  /// Rebaixa um instrutor a aluno. Não desfaz vínculos já existentes
  /// (alunos vinculados, planos criados) — ficam órfãos, mas inofensivos.
  Future<void> demoteToStudent(UserProfile user) async {
    await _firestoreService.updateUserProfile(
      user.copyWith(role: UserRole.student),
    );
  }

  Future<void> saveExercise(Exercise exercise) {
    return _firestoreService.seedExercise(exercise);
  }

  Future<void> deleteExercise(String id) {
    return _firestoreService.deleteExercise(id);
  }

  Future<AdminStats> loadStats() async {
    final results = await Future.wait([
      _firestoreService.countUsers(),
      _firestoreService.countUsersByRole('student'),
      _firestoreService.countUsersByRole('instructor'),
      _firestoreService.countExercises(),
      _firestoreService.countWorkoutsLogged(),
    ]);
    return AdminStats(
      totalUsers: results[0],
      totalStudents: results[1],
      totalInstructors: results[2],
      totalExercises: results[3],
      totalWorkoutsLogged: results[4],
    );
  }
}
