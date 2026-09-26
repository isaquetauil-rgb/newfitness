import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/ai/logic/chat_provider.dart'
    show maxAiMessageLength;
import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/shared/models/nutrition_message.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Chat de nutrição — três participantes: o aluno pergunta, a IA responde
/// na hora, e a nutricionista vinculada pode entrar depois pra corrigir ou
/// validar a resposta (mensagens ficam todas na mesma conversa, em
/// `users/{studentUid}/nutrition_chat`). Isolado do chat geral
/// ([ChatProvider]) e do domínio do instrutor — ver `firestore.rules`.
class NutritionChatProvider extends ChangeNotifier {
  NutritionChatProvider({
    AiService? aiService,
    FirestoreService? firestoreService,
  }) : _aiService = aiService ?? getIt<AiService>(),
       _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final AiService _aiService;
  final FirestoreService _firestoreService;

  bool _sending = false;
  bool get isSending => _sending;

  String? _error;
  String? get error => _error;

  Stream<List<NutritionMessage>> watchMessages(String studentUid) {
    return _firestoreService.watchNutritionChat(studentUid);
  }

  /// Chamado pelo aluno: grava a pergunta e chama a IA. A RESPOSTA é
  /// gravada na conversa pela própria Cloud Function `askNutritionAI` — as
  /// regras não deixam nenhum cliente criar mensagens `assistant` (senão um
  /// aluno poderia forjar uma "resposta da IA" na conversa que a
  /// nutricionista acompanha). Ela aparece pelo stream de [watchMessages].
  ///
  /// O histórico enviado à IA é montado pelo servidor a partir da conversa.
  Future<void> ask(String studentUid, String text) async {
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
      final userMessage = NutritionMessage(
        id: '',
        role: NutritionRole.user,
        content: message,
        createdAt: DateTime.now(),
      );
      await _firestoreService.addNutritionMessage(studentUid, userMessage);
      await _aiService.askNutrition(message: message);
    } catch (e) {
      // Mensagem real do servidor quando existe (ex: limite mensal do
      // plano, e-mail não verificado, IA demorou).
      _error = e is AppException ? e.message : 'Não foi possível falar com a IA agora. Tente de novo em instantes.';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Chamado pela nutricionista: adiciona uma correção/validação visível
  /// pro aluno na mesma conversa.
  Future<void> addCorrection(
    String studentUid,
    String text,
    String nutritionistName,
  ) {
    if (text.trim().isEmpty) return Future.value();
    return _firestoreService.addNutritionMessage(
      studentUid,
      NutritionMessage(
        id: '',
        role: NutritionRole.nutritionist,
        content: text.trim(),
        createdAt: DateTime.now(),
        authorName: nutritionistName,
      ),
    );
  }
}
