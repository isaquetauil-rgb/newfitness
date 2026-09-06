import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/ai/data/ai_service.dart';

/// Estado efêmero (não persistido no Firestore) do assistente de IA usado
/// pelo instrutor — tanto para pedidos gerais ("mais ideias de treino de
/// braço") quanto contextualizados a um aluno específico ("dor nas
/// costas da Dona Maria").
class InstructorAiProvider extends ChangeNotifier {
  InstructorAiProvider({AiService? aiService})
    : _aiService = aiService ?? getIt<AiService>();

  final AiService _aiService;

  bool _loading = false;
  String? _error;
  String? _suggestion;

  bool get isLoading => _loading;
  String? get error => _error;
  String? get suggestion => _suggestion;

  Future<void> ask({required String prompt, String? studentName}) async {
    if (prompt.trim().isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _suggestion = await _aiService.suggestTrainingPlan(
        prompt: prompt.trim(),
        studentName: studentName,
      );
    } catch (e) {
      _error =
          'Não foi possível falar com a IA agora. Tente de novo em instantes.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _loading = false;
    _error = null;
    _suggestion = null;
    notifyListeners();
  }
}
