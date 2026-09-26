import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/shared/models/chat_message.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Tamanho máximo de uma pergunta (o mesmo das regras e da Function).
const maxAiMessageLength = 2000;

class ChatProvider extends ChangeNotifier {
  final AiService _aiService;
  final FirestoreService _firestoreService;

  ChatProvider({AiService? aiService, FirestoreService? firestoreService})
    : _aiService = aiService ?? getIt<AiService>(),
      _firestoreService = firestoreService ?? getIt<FirestoreService>();

  bool _sending = false;
  bool get isSending => _sending;

  String? _error;
  String? get error => _error;

  Stream<List<ChatMessage>> watchMessages(String uid) {
    return _firestoreService.watchChatMessages(uid);
  }

  /// Grava a pergunta do usuário e chama a IA. A resposta é gravada na
  /// conversa pela própria Cloud Function `chatWithAI` (as regras não
  /// deixam o app gravar mensagens `assistant`) e aparece pelo stream de
  /// [watchMessages]. O histórico enviado à IA é montado pelo servidor.
  Future<void> sendMessage(String uid, String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    if (message.length > maxAiMessageLength) {
      _error = 'A pergunta pode ter no máximo $maxAiMessageLength caracteres.';
      notifyListeners();
      return;
    }
    _sending = true;
    _error = null;
    notifyListeners();

    try {
      final userMessage = ChatMessage(
        id: '',
        role: ChatRole.user,
        content: message,
        createdAt: DateTime.now(),
      );
      await _firestoreService.addChatMessage(uid, userMessage);
      await _aiService.chat(message: message);
    } catch (e) {
      // Mensagem real do servidor quando existe (ex: limite diário do
      // plano, e-mail não verificado, IA demorou).
      _error = e is AppException ? e.message : 'Não foi possível falar com a IA agora. Tente de novo em instantes.';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
