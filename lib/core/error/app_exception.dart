/// Hierarquia de exceções tipadas usada pelos services (`shared/services`,
/// `features/*/data`) para traduzir falhas de baixo nível (Firebase, rede,
/// I/O) em erros com significado para quem chama — sem perder a causa
/// original, que fica em [cause] para logging.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  /// Mensagem já pronta para exibir ao usuário (PT-BR).
  final String message;

  /// Exceção original que gerou este erro, se houver.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

/// Falha de conectividade ou comunicação com um serviço remoto
/// (Firestore, Storage, Cloud Functions).
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

/// Falha de autenticação/autorização (login, permissão negada).
class AuthException extends AppException {
  const AuthException(super.message, {super.cause, super.stackTrace});
}

/// O recurso pedido não existe (documento, usuário, arquivo).
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause, super.stackTrace});
}

/// Dados de entrada inválidos (validação de formulário/regra de negócio).
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause, super.stackTrace});
}

/// Qualquer outra falha não classificada.
class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause, super.stackTrace});
}
