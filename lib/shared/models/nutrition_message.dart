/// Quem escreveu uma mensagem no chat de nutrição — diferente de
/// [ChatRole] (que só tem `user`/`assistant`) porque aqui existe um
/// terceiro participante: a nutricionista vinculada, que pode corrigir ou
/// validar a resposta da IA (ver `firestore.rules`, que trava cada papel a
/// só poder escrever a própria mensagem).
enum NutritionRole { user, assistant, nutritionist }

NutritionRole _nutritionRoleFromString(String? value) {
  switch (value) {
    case 'assistant':
      return NutritionRole.assistant;
    case 'nutritionist':
      return NutritionRole.nutritionist;
    default:
      return NutritionRole.user;
  }
}

String _nutritionRoleToString(NutritionRole role) {
  switch (role) {
    case NutritionRole.assistant:
      return 'assistant';
    case NutritionRole.nutritionist:
      return 'nutritionist';
    case NutritionRole.user:
      return 'user';
  }
}

/// Uma mensagem em `users/{uid}/nutrition_chat` — pergunta do aluno,
/// resposta da IA, ou correção/validação da nutricionista vinculada.
class NutritionMessage {
  final String id;
  final NutritionRole role;
  final String content;
  final DateTime createdAt;

  /// Nome de quem escreveu, só preenchido pra mensagens da nutricionista —
  /// o aluno vê "Dra. Fulana corrigiu:" em vez de um `role` cru.
  final String? authorName;

  const NutritionMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.authorName,
  });

  factory NutritionMessage.fromMap(String id, Map<String, dynamic> map) {
    return NutritionMessage(
      id: id,
      role: _nutritionRoleFromString(map['role'] as String?),
      content: map['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      authorName: map['authorName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': _nutritionRoleToString(role),
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'authorName': authorName,
    };
  }
}
