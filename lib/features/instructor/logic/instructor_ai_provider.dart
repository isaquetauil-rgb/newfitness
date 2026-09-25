import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/shared/models/exercise_suggestion.dart';

/// Estado efêmero (não persistido no Firestore) do assistente de IA usado
/// pelo instrutor — tanto para pedidos gerais ("mais ideias de treino de
/// braço") quanto contextualizados a um aluno específico ("dor nas
/// costas da Dona Maria"). Cada pedido devolve de 3 a 4 sugestões de
/// exercício estruturadas (ver [ExerciseSuggestion]).
class InstructorAiProvider extends ChangeNotifier {
  InstructorAiProvider({AiService? aiService})
    : _aiService = aiService ?? getIt<AiService>();

  final AiService _aiService;

  bool _loading = false;
  String? _error;
  List<ExerciseSuggestion> _suggestions = [];
  String? _rawText;

  bool get isLoading => _loading;
  String? get error => _error;
  List<ExerciseSuggestion> get suggestions => _suggestions;

  /// Preenchido só quando a IA não devolveu um JSON válido — fallback pra
  /// não perder a resposta.
  String? get rawText => _rawText;

  Future<void> ask({required String prompt, String? studentName}) async {
    if (prompt.trim().isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _aiService.suggestTrainingPlan(
        prompt: prompt.trim(),
        studentName: studentName,
      );
      _suggestions = result.suggestions;
      _rawText = result.rawText;
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
    _suggestions = [];
    _rawText = null;
    notifyListeners();
  }
}
