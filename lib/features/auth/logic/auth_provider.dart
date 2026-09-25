import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:newfitness/core/constants/admin_config.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/core/network/functions_client.dart';
import 'package:newfitness/features/auth/data/auth_service.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

final _log = AppLogger.of('AuthProvider');

/// Mantém o estado de autenticação e o perfil do usuário logado,
/// e notifica a árvore de widgets quando algo muda.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    FirestoreService? firestoreService,
    FunctionsClient? functionsClient,
  }) : _authService = authService ?? getIt<AuthService>(),
       _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _functionsClientOverride = functionsClient {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  final AuthService _authService;
  final FirestoreService _firestoreService;

  // `FunctionsClient()` toca `FirebaseFunctions.instance` assim que é
  // construído — por isso só cria uma instância de verdade na primeira vez
  // que algo realmente precisa chamar uma Cloud Function (`signUp` com
  // código, `linkToInstructor`/`linkToNutritionist`), nunca na construção
  // do próprio `AuthProvider`. Sem isso, todo teste/tela que monta um
  // `AuthProvider` (mesmo sem nunca vincular ninguém) exigiria o Firebase
  // inicializado.
  final FunctionsClient? _functionsClientOverride;
  FunctionsClient? _lazyFunctionsClient;
  FunctionsClient get _functionsClient =>
      _functionsClientOverride ?? (_lazyFunctionsClient ??= FunctionsClient());

  StreamSubscription<User?>? _authSub;

  User? _user;
  UserProfile? _profile;
  bool _loading = false;
  bool _loadingProfile = false;
  String? _errorMessage;
  String? _profileError;

  // true durante [signUp]: o Firebase Auth já avisa que o usuário entrou
  // (authStateChanges) antes de o perfil com o papel escolhido ser gravado.
  // Sem isso, [_loadProfile] não achava o documento e criava um perfil
  // padrão de ALUNO por cima — quem se cadastrava como instrutor/
  // nutricionista ficava como aluno (ou tinha a gravação negada pelas regras).
  bool _signingUp = false;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  /// true se a conta logada já confirmou o e-mail (link de verificação).
  bool get isEmailVerified => _user?.emailVerified ?? false;

  /// Único usuário com acesso ao painel de administração: e-mail do dono E
  /// e-mail verificado — o mesmo critério das regras do Firestore e das
  /// Functions (`email` + `email_verified` do token), que são a barreira de
  /// segurança real; isso só controla o que a UI mostra.
  bool get isAdmin =>
      _user?.email?.toLowerCase() == ownerEmail.toLowerCase() &&
      isEmailVerified;

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
      var profile = await _firestoreService.getUserProfile(uid);
      // Cadastro em andamento: quem grava o perfil é o próprio [signUp].
      if (profile == null && _signingUp) return;
      // Conta autenticada sem documento de perfil (ex: a escrita falhou no
      // cadastro por algum motivo pontual) — em vez de travar o usuário
      // numa tela de erro, cria um perfil padrão automaticamente com os
      // dados já disponíveis no Firebase Auth.
      profile ??= await _createDefaultProfile(uid);
      _profile = await _withInviteCode(profile);
    } catch (e, st) {
      _log.warning('Falha ao carregar perfil de $uid', e, st);
      _profileError = _authService.friendlyError(e);
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  /// Instrutor/nutricionista: confirma o código de convite com a Cloud
  /// Function `ensureInviteCode` — a única que pode gravá-lo. Cobre quem
  /// acabou de se cadastrar, quem foi promovido pelo admin e quem ainda tem
  /// um código antigo (gerado no app, sem reserva): a função o reserva se
  /// for exclusivo ou emite um novo se alguém tiver copiado. É idempotente.
  /// Falha não é fatal: o perfil carrega com o que tiver e tenta de novo no
  /// próximo carregamento.
  Future<UserProfile> _withInviteCode(UserProfile profile) async {
    final isProfessional =
        profile.role == UserRole.instructor ||
        profile.role == UserRole.nutritionist;
    if (!isProfessional) return profile;
    try {
      final result = await _functionsClient.call('ensureInviteCode', {});
      final code = result['code'] as String?;
      return code == null || code == profile.inviteCode
          ? profile
          : profile.copyWith(inviteCode: code);
    } catch (e, st) {
      _log.warning('Falha ao obter o código de convite', e, st);
      return profile;
    }
  }

  Future<UserProfile> _createDefaultProfile(String uid) async {
    _log.info('Perfil não encontrado para $uid — criando um padrão.');
    final profile = UserProfile(
      uid: uid,
      name: _user?.displayName?.trim().isNotEmpty == true
          ? _user!.displayName!.trim()
          : (_user?.email?.split('@').first ?? 'Usuário'),
      email: _user?.email ?? '',
    );
    await _firestoreService.createUserProfile(profile);
    return profile;
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

  /// O cadastro é SEMPRE de aluno — personal/nutricionista pedem a
  /// aprovação depois, no app (`professional_requests`), e as regras não
  /// deixam o cliente criar perfil com outro papel. [instructorCode] e
  /// [nutritionistCode] são opcionais e independentes (um aluno pode ter os
  /// dois, um só, ou nenhum).
  ///
  /// A conta e o perfil são criados primeiro (sem vínculo nenhum —
  /// `firestore.rules` proíbe o cliente de já criar o documento com
  /// `instructorId`/`nutritionistId` preenchidos); o vínculo em si é pedido
  /// depois à Cloud Function `linkToProfessional`, que valida o código no
  /// servidor. Um código inválido não desfaz o cadastro: só aquele vínculo
  /// específico fica pendente, e o aluno pode tentar de novo na tela de
  /// Perfil (`AuthProvider.linkToInstructor`/`linkToNutritionist`).
  Future<bool> signUp(
    String name,
    String email,
    String password, {
    String? instructorCode,
    String? nutritionistCode,
  }) async {
    _signingUp = true;
    final ok = await _run(() async {
      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      if (user == null) return;

      final newProfile = UserProfile(uid: user.uid, name: name, email: email);
      await _firestoreService.createUserProfile(newProfile);
      _profile = newProfile;

      if (instructorCode != null && instructorCode.trim().isNotEmpty) {
        await _tryLinkDuringSignUp(instructorCode, 'instructor');
      }
      if (nutritionistCode != null && nutritionistCode.trim().isNotEmpty) {
        await _tryLinkDuringSignUp(nutritionistCode, 'nutritionist');
      }
    });
    _signingUp = false;
    // Conta criada, mas a gravação do perfil falhou: carrega/cria o perfil
    // padrão para o usuário não ficar logado sem perfil.
    if (_user != null && _profile == null) await _loadProfile(_user!.uid);
    return ok;
  }

  /// Não deixa um código inválido derrubar o cadastro inteiro — a conta já
  /// foi criada com sucesso nesse ponto; só o vínculo em si fica pendente.
  Future<void> _tryLinkDuringSignUp(String code, String kind) async {
    try {
      await _functionsClient.call('linkToProfessional', {
        'code': code,
        'kind': kind,
      });
      final refreshed = await _firestoreService.getUserProfile(_profile!.uid);
      if (refreshed != null) _profile = refreshed;
    } catch (e, st) {
      _log.warning('Falha ao vincular durante o cadastro ($kind)', e, st);
    }
  }

  /// Vincula o usuário logado (aluno) a um instrutor pelo código de convite
  /// — valida no servidor via Cloud Function (ver `linkToInstructor` em
  /// `functions/src/linking.ts`) e nunca escreve `instructorId` diretamente
  /// (as regras do Firestore não permitiriam). Devolve o nome do instrutor
  /// em caso de sucesso, ou `null` (com [errorMessage] preenchido) se falhar.
  Future<String?> linkToInstructor(String code) =>
      _linkToProfessional(code, 'instructor');

  /// Mesmo que [linkToInstructor], para nutricionista.
  Future<String?> linkToNutritionist(String code) =>
      _linkToProfessional(code, 'nutritionist');

  /// Desfaz o vínculo com o instrutor pela Cloud Function
  /// `unlinkFromProfessional` (o app nunca escreve `instructorId`). O
  /// histórico do aluno não é apagado. Devolve false com [errorMessage]
  /// preenchido se falhar.
  Future<bool> unlinkFromInstructor() => _unlinkFrom('instructor');

  /// Mesmo que [unlinkFromInstructor], para nutricionista.
  Future<bool> unlinkFromNutritionist() => _unlinkFrom('nutritionist');

  Future<bool> _unlinkFrom(String kind) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _functionsClient.call('unlinkFromProfessional', {'kind': kind});
      final uid = _user?.uid;
      if (uid != null) await _loadProfile(uid);
      return true;
    } catch (e) {
      _errorMessage = e is AppException
          ? e.message
          : 'Não foi possível desvincular. Tente de novo.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> _linkToProfessional(String code, String kind) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _functionsClient.call('linkToProfessional', {
        'code': code,
        'kind': kind,
      });
      final uid = _user?.uid;
      if (uid != null) await _loadProfile(uid);
      _loading = false;
      notifyListeners();
      return result['name'] as String?;
    } catch (e) {
      _loading = false;
      _errorMessage = e is AppException
          ? e.message
          : 'Não foi possível vincular. Tente de novo.';
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() => _authService.signOut();

  Future<void> refreshProfile() async {
    final uid = _user?.uid;
    if (uid != null) await _loadProfile(uid);
  }

  Future<bool> resetPassword(String email) {
    return _run(() => _authService.sendPasswordResetEmail(email));
  }

  /// Envia o e-mail de verificação para a conta logada.
  Future<bool> sendEmailVerification() {
    return _run(() => _authService.sendEmailVerification());
  }

  /// "Já verifiquei": recarrega a conta e o token para [isEmailVerified]
  /// (e as regras do Firestore) enxergarem a verificação sem sair da conta.
  Future<bool> reloadUser() {
    return _run(() async {
      final fresh = await _authService.reloadCurrentUser();
      if (fresh != null) _user = fresh;
    });
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
