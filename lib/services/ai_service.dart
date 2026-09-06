import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

/// Encapsula as chamadas às Cloud Functions de IA. A chave de API nunca
/// fica no app — ela mora só no backend (veja functions/README.md).
class AiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final callable = _functions.httpsCallable('chatWithAI');
    final result = await callable.call({
      'message': message,
      'history': history,
    });
    return (result.data as Map)['reply'] as String? ?? '';
  }

  Future<String> analyzeMealPhoto({
    required File image,
    required String mealType,
  }) async {
    final bytes = await image.readAsBytes();
    final callable = _functions.httpsCallable('analyzeMealPhoto');
    final result = await callable.call({
      'imageBase64': base64Encode(bytes),
      'mediaType': 'image/jpeg',
      'mealType': mealType,
    });
    return (result.data as Map)['analysis'] as String? ?? '';
  }

  Future<String> analyzeBodyPhoto({required File image}) async {
    final bytes = await image.readAsBytes();
    final callable = _functions.httpsCallable('analyzeBodyPhoto');
    final result = await callable.call({
      'imageBase64': base64Encode(bytes),
      'mediaType': 'image/jpeg',
    });
    return (result.data as Map)['analysis'] as String? ?? '';
  }
}
