import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/shared/models/chat_message.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

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

  Future<void> sendMessage(
    String uid,
    String text,
    List<ChatMessage> historySoFar,
  ) async {
    if (text.trim().isEmpty) return;
    _sending = true;
    _error = null;
    notifyListeners();

    final userMessage = ChatMessage(
      id: '',
      role: ChatRole.user,
      content: text.trim(),
      createdAt: DateTime.now(),
    );
    await _firestoreService.addChatMessage(uid, userMessage);

    try {
      final history = historySoFar
          .map(
            (m) => {
              'role': m.role == ChatRole.assistant ? 'assistant' : 'user',
              'content': m.content,
            },
          )
          .toList();

      final reply = await _aiService.chat(
        message: text.trim(),
        history: history,
      );

      final assistantMessage = ChatMessage(
        id: '',
        role: ChatRole.assistant,
        content: reply.isEmpty
            ? 'Desculpe, não consegui responder agora.'
            : reply,
        createdAt: DateTime.now(),
      );
      await _firestoreService.addChatMessage(uid, assistantMessage);
    } catch (e) {
      _error =
          'Não foi possível falar com a IA agora. Tente de novo em instantes.';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
