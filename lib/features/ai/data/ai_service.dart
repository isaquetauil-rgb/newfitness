import 'package:newfitness/core/network/functions_client.dart';
import 'package:newfitness/shared/models/exercise_suggestion.dart';

/// Encapsula as chamadas às Cloud Functions de IA. A chave de API nunca
/// fica no app — ela mora só no backend (veja functions/README.md).
/// Tratamento de erro (rede, autenticação, cota, argumentos inválidos) é
/// feito de forma uniforme pelo [FunctionsClient].
///
/// O histórico das conversas é montado pelo servidor a partir do Firestore
/// e as respostas da IA (chat, nutrição e análise de refeição) são gravadas
/// por ele — o app só envia a pergunta ou o id da foto.
class AiService {
  AiService({FunctionsClient? client}) : _client = client ?? FunctionsClient();

  final FunctionsClient _client;

  /// A Function da nutrição espera até 100 s pela IA (busca na web); o app
  /// espera um pouco mais que o limite dela (120 s).
  static const nutritionTimeout = Duration(seconds: 130);

  Future<String> chat({required String message}) async {
    final data = await _client.call('chatWithAI', {'message': message});
    return data['reply'] as String? ?? '';
  }

  /// Chat de nutrição — conversa isolada que a nutricionista vinculada
  /// também acompanha (ver `NutritionChatProvider`).
  Future<String> askNutrition({required String message}) async {
    final data = await _client.call('askNutritionAI', {
      'message': message,
    }, timeout: nutritionTimeout);
    return data['reply'] as String? ?? '';
  }

  /// Pede a análise da foto de refeição JÁ SALVA [photoId]; o servidor lê a
  /// imagem do Storage e grava o resultado no documento da foto.
  Future<String> analyzeMealPhoto({required String photoId}) async {
    final data = await _client.call('analyzeMealPhoto', {'photoId': photoId});
    return data['analysis'] as String? ?? '';
  }

  /// Pede à IA de 3 a 4 sugestões de exercício para apoiar o instrutor —
  /// geral (sem [studentUid]) ou contextualizada a um aluno vinculado (o
  /// servidor lê o nome dele pelo uid).
  Future<TrainingSuggestionResult> suggestTrainingPlan({
    required String prompt,
    String? studentUid,
  }) async {
    final payload = <String, dynamic>{'prompt': prompt};
    if (studentUid != null) payload['studentUid'] = studentUid;
    final data = await _client.call('suggestTrainingPlan', payload);
    return TrainingSuggestionResult.fromMap(data);
  }
}
