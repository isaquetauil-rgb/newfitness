import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/data/auth_service.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Mantém o estado de autenticação e o perfil do usuário logado,
/// e notifica a árvore de widgets quando algo muda.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, FirestoreService? firestoreService})
    : _authService = authService ?? getIt<AuthService>(),
      _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  final AuthService _authService;
  final FirestoreService _firestoreService;

  StreamSubscription<User?>? _authSub;

  User? _user;
  UserProfile? _profile;
  bool _loading = false;
  String? _errorMessage;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    if (user != null) {
      _profile = await _firestoreService.getUserProfile(user.uid);
    } else {
      _profile = null;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    return _run(() async {
      await _authService.signIn(email: email, password: password);
    });
  }

  /// [instructorCode] só é usado quando [role] é [UserRole.student]. Se
  /// informado, é validado ANTES de criar a conta — assim, se o código
  /// estiver errado, nenhuma conta é criada e o usuário pode corrigir.
  Future<bool> signUp(
    String name,
    String email,
    String password, {
    UserRole role = UserRole.student,
    String? instructorCode,
  }) async {
    return _run(() async {
      String? validatedInstructorId;

      if (role == UserRole.student &&
          instructorCode != null &&
          instructorCode.trim().isNotEmpty) {
        final instructor = await _firestoreService.findInstructorByCode(
          instructorCode,
        );
        if (instructor == null) {
          throw Exception(
            'Código de instrutor inválido. Confira e tente de novo.',
          );
        }
        validatedInstructorId = instructor.uid;
      }

      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      if (user == null) return;

      String? inviteCode;
      if (role == UserRole.instructor) {
        inviteCode = await _firestoreService.generateUniqueInviteCode();
      }

      final newProfile = UserProfile(
        uid: user.uid,
        name: name,
        email: email,
        role: role,
        inviteCode: inviteCode,
        instructorId: validatedInstructorId,
      );
      await _firestoreService.createUserProfile(newProfile);

      if (validatedInstructorId != null) {
        await _firestoreService.linkStudentToInstructor(
          student: newProfile,
          instructorId: validatedInstructorId,
        );
      }

      _profile = newProfile;
    });
  }

  Future<void> signOut() => _authService.signOut();

  Future<void> refreshProfile() async {
    if (_user == null) return;
    _profile = await _firestoreService.getUserProfile(_user!.uid);
    notifyListeners();
  }

  Future<bool> resetPassword(String email) {
    return _run(() => _authService.sendPasswordResetEmail(email));
  }

  Future<bool> _run(Future<void> Function() action) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _loading = false;
      _errorMessage = _authService.friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
