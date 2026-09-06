import 'dart:convert';
import 'dart:io';

import 'package:newfitness/core/network/functions_client.dart';

/// Encapsula as chamadas às Cloud Functions de IA. A chave de API nunca
/// fica no app — ela mora só no backend (veja functions/README.md).
/// Tratamento de erro (rede, autenticação, argumentos inválidos) é feito
/// de forma uniforme pelo [FunctionsClient].
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

  Future<String> analyzeMealPhoto({
    required File image,
    required String mealType,
  }) async {
    final bytes = await image.readAsBytes();
    final data = await _client.call('analyzeMealPhoto', {
      'imageBase64': base64Encode(bytes),
      'mediaType': 'image/jpeg',
      'mealType': mealType,
    });
    return data['analysis'] as String? ?? '';
  }

  Future<String> analyzeBodyPhoto({required File image}) async {
    final bytes = await image.readAsBytes();
    final data = await _client.call('analyzeBodyPhoto', {
      'imageBase64': base64Encode(bytes),
      'mediaType': 'image/jpeg',
    });
    return data['analysis'] as String? ?? '';
  }
}
