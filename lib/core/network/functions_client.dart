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

  ///
  /// [timeout] muda o tempo máximo de espera do app (padrão do SDK: 60 s) —
  /// para Functions que podem demorar mais, como a de nutrição com busca.
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    Duration? timeout,
  }) async {
    try {
      final callable = timeout == null
          ? _functions.httpsCallable(name)
          : _functions.httpsCallable(
              name,
              options: HttpsCallableOptions(timeout: timeout),
            );
      final result = await callable.call(data);
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
        // Cota de IA atingida — a mensagem amigável (qual limite, quando
        // renova) já vem pronta de `reserveAiQuota` no backend.
        return ValidationException(
          e.message ?? 'Limite de uso atingido.',
          cause: e,
          stackTrace: stack,
        );
      case 'failed-precondition':
        // Ex: "Atualize o app para ver a análise da IA."
        return ValidationException(
          e.message ?? 'Não foi possível concluir agora.',
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
        // As Functions de IA mandam frases prontas começando com "A IA"
        // (demorou / muita procura); qualquer outra origem (sem rede, tempo
        // do app esgotado) usa a mensagem genérica.
        final serverMessage = e.message;
        return NetworkException(
          serverMessage != null && serverMessage.startsWith('A IA')
              ? serverMessage
              : 'Sem conexão com o servidor. Tente novamente.',
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
