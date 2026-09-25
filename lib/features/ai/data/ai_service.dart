import 'dart:convert';
import 'dart:typed_data';

import 'package:newfitness/core/network/functions_client.dart';
import 'package:newfitness/shared/models/exercise_suggestion.dart';

/// Encapsula as chamadas às Cloud Functions de IA. A chave de API nunca
/// fica no app — ela mora só no backend (veja functions/README.md).
/// Tratamento de erro (rede, autenticação, argumentos inválidos) é feito
/// de forma uniforme pelo [FunctionsClient].
///
/// Os métodos de análise de foto recebem `Uint8List` (não `dart:io.File`)
/// de propósito — funciona igual em Android/iOS/Web.
class AiService {
  AiService({FunctionsClient? client}) : _client = client ?? FunctionsClient();

  final FunctionsClient _client;

  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final data = await _client.call('chatWithAI', {
      'message': message,
      'history': history,
    });
    return data['reply'] as String? ?? '';
  }

  /// Chat de nutrição — mesma forma de `chat`, mas conversa isolada que a
  /// nutricionista vinculada também acompanha (ver `NutritionChatProvider`).
  Future<String> askNutrition({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final data = await _client.call('askNutritionAI', {
      'message': message,
      'history': history,
    });
    return data['reply'] as String? ?? '';
  }

  Future<String> analyzeMealPhoto({
    required Uint8List imageBytes,
    required String mealType,
  }) async {
    final data = await _client.call('analyzeMealPhoto', {
      'imageBase64': base64Encode(imageBytes),
      'mediaType': 'image/jpeg',
      'mealType': mealType,
    });
    return data['analysis'] as String? ?? '';
  }

  Future<String> analyzeBodyPhoto({required Uint8List imageBytes}) async {
    final data = await _client.call('analyzeBodyPhoto', {
      'imageBase64': base64Encode(imageBytes),
      'mediaType': 'image/jpeg',
    });
    return data['analysis'] as String? ?? '';
  }

  /// Pede à IA de 3 a 4 sugestões de exercício para apoiar o instrutor —
  /// geral (sem [studentName]) ou contextualizada a um aluno específico.
  Future<TrainingSuggestionResult> suggestTrainingPlan({
    required String prompt,
    String? studentName,
  }) async {
    final payload = <String, dynamic>{'prompt': prompt};
    if (studentName != null) payload['studentName'] = studentName;
    final data = await _client.call('suggestTrainingPlan', payload);
    return TrainingSuggestionResult.fromMap(data);
  }
}
