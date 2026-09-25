import 'package:cloud_functions/cloud_functions.dart';

import '../error/app_exception.dart';
import '../logging/app_logger.dart';

final _log = AppLogger.of('FunctionsClient');

/// Chama uma Cloud Function *callable* com tratamento de erro uniforme,
/// convertendo [FirebaseFunctionsException]/falhas de rede em [AppException]
/// tipadas em vez de deixá-las vazar cruas para a UI. Usado por
/// [AiService] (chat e análise de fotos via Claude).
class FunctionsClient {
  FunctionsClient({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final response = result.data;
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      throw UnknownException('Resposta inesperada de "$name".');
    } on FirebaseFunctionsException catch (e, stack) {
      _log.warning('Falha ao chamar "$name": ${e.code}', e, stack);
      throw _mapFunctionsError(name, e, stack);
    } catch (e, stack) {
      _log.severe('Erro inesperado ao chamar "$name"', e, stack);
      throw NetworkException(
        'Não foi possível conectar. Verifique sua internet.',
        cause: e,
        stackTrace: stack,
      );
    }
  }

  AppException _mapFunctionsError(
    String name,
    FirebaseFunctionsException e,
    StackTrace stack,
  ) {
    switch (e.code) {
      case 'unauthenticated':
        return AuthException(
          'Você precisa estar logado para usar este recurso.',
          cause: e,
          stackTrace: stack,
        );
      case 'invalid-argument':
        // As Functions já mandam mensagens prontas para o usuário (ex:
        // "Código de instrutor inválido.") — antes elas eram trocadas por
        // um texto técnico com o nome da Function.
        return ValidationException(
          e.message ?? 'Dados inválidos.',
          cause: e,
          stackTrace: stack,
        );
      case 'resource-exhausted':
        // Limite mensal de uso de IA do plano Básico atingido — a mensagem
        // amigável já vem pronta de `assertAiUsageAllowed` no backend.
        return ValidationException(
          e.message ?? 'Limite de uso atingido.',
          cause: e,
          stackTrace: stack,
        );
      case 'permission-denied':
        return AuthException(
          e.message ?? 'Você não tem permissão para fazer isso.',
          cause: e,
          stackTrace: stack,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return NetworkException(
          'Sem conexão com o servidor. Tente novamente.',
          cause: e,
          stackTrace: stack,
        );
      default:
        return UnknownException(
          e.message ?? 'Erro ao chamar "$name".',
          cause: e,
          stackTrace: stack,
        );
    }
  }
}
