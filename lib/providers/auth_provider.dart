import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Mantém o estado de autenticação e o perfil do usuário logado,
/// e notifica a árvore de widgets quando algo muda.
class AuthProvider extends ChangeNotifier {
  final AuthService? _authService;
  final FirestoreService? _firestoreService;

  AuthProvider({AuthService? authService, FirestoreService? firestoreService})
    : _authService = authService ?? AuthService(),
      _firestoreService = firestoreService ?? FirestoreService() {
    _authSub = _authService!.authStateChanges.listen(_onAuthChanged);
  }

  AuthProvider.test() : _authService = null, _firestoreService = null;

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
      _profile = await _firestoreService!.getUserProfile(user.uid);
    } else {
      _profile = null;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    return _run(() async {
      await _authService!.signIn(email: email, password: password);
    });
  }

  Future<bool> signUp(String name, String email, String password) async {
    return _run(() async {
      final user = await _authService!.signUp(
        email: email,
        password: password,
        name: name,
      );
      if (user != null) {
        final newProfile = UserProfile(uid: user.uid, name: name, email: email);
        await _firestoreService!.createUserProfile(newProfile);
        _profile = newProfile;
      }
    });
  }

  Future<void> signOut() => _authService!.signOut();

  Future<void> refreshProfile() async {
    if (_user == null) return;
    _profile = await _firestoreService!.getUserProfile(_user!.uid);
    notifyListeners();
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
      _errorMessage = _authService!.friendlyError(e);
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
