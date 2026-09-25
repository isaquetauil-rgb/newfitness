import 'package:firebase_auth/firebase_auth.dart';

/// Encapsula toda a comunicação com o Firebase Authentication.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    return credential.user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Envia o e-mail de verificação para a conta logada.
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Recarrega a conta logada (para ler o `emailVerified` atualizado depois
  /// que a pessoa clicou no link) e força um token novo — as regras e as
  /// Functions leem `email_verified` do token, não da conta.
  Future<User?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final fresh = _auth.currentUser;
    await fresh?.getIdToken(true);
    return fresh;
  }

  /// Converte os códigos de erro do Firebase em mensagens legíveis em PT-BR.
  String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-disabled':
          return 'Esta conta foi desativada.';
        case 'user-not-found':
          return 'Nenhuma conta encontrada com esse e-mail.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'email-already-in-use':
          return 'Já existe uma conta com esse e-mail.';
        case 'weak-password':
          return 'A senha precisa ter pelo menos 6 caracteres.';
        default:
          return 'Erro: ${error.message ?? error.code}';
      }
    }
    if (error is Exception) {
      // Mensagens de validação lançadas pelo próprio app (ex: código de
      // instrutor inválido) já vêm prontas para exibir ao usuário.
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.isNotEmpty) return message;
    }
    return 'Ocorreu um erro inesperado. Tente novamente.';
  }
}
