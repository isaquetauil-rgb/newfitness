import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/features/auth/data/auth_service.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

final _log = AppLogger.of('AuthProvider');

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
  bool _loadingProfile = false;
  String? _errorMessage;
  String? _profileError;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  /// true enquanto o perfil do usuário logado ainda está sendo buscado no
  /// Firestore — a UI pode usar isso para mostrar um spinner só nesse
  /// período, em vez de indefinidamente quando [profile] nunca chega a
  /// carregar (ver [profileError]).
  bool get isLoadingProfile => _loadingProfile;

  /// Mensagem amigável quando a busca do perfil falha (ex: regras do
  /// Firestore bloqueando a leitura) — permite a UI mostrar um erro com
  /// opção de tentar de novo, em vez de girar para sempre.
  String? get profileError => _profileError;

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    if (user == null) {
      _profile = null;
      _profileError = null;
      _loadingProfile = false;
      notifyListeners();
      return;
    }
    await _loadProfile(user.uid);
  }

  Future<void> _loadProfile(String uid) async {
    _loadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      _profile = await _firestoreService.getUserProfile(uid);
      if (_profile == null) {
        _profileError =
            'Não encontramos seu perfil. Tente sair e entrar novamente.';
      }
    } catch (e, st) {
      _log.warning('Falha ao carregar perfil de $uid', e, st);
      _profileError = _authService.friendlyError(e);
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  /// Tenta buscar o perfil de novo (usado pela UI num botão "Tentar de novo").
  Future<void> retryLoadProfile() async {
    final uid = _user?.uid;
    if (uid != null) await _loadProfile(uid);
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
    final uid = _user?.uid;
    if (uid != null) await _loadProfile(uid);
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
