/// PAR-Q (Physical Activity Readiness Questionnaire): as 7 perguntas padrão
/// de prontidão para atividade física, respondidas pelo aluno na primeira
/// visita. Fica no perfil (`users/{uid}.parq`, campo opcional) com a data.
///
/// Diferente do questionário dos treinos de saúde (`HealthScreening`), o
/// PAR-Q não bloqueia nada: com algum "sim", o app recomenda liberação
/// médica antes de treinar e o personal vinculado vê o resultado.
class ParQ {
  const ParQ({
    required this.answers,
    required this.answeredAt,
    this.version = parqVersion,
  });

  /// Uma resposta por pergunta de [parqQuestions]; `true` = sim.
  final List<bool> answers;

  /// Milissegundos desde a época.
  final int answeredAt;
  final int version;

  /// Algum "sim": recomendar liberação médica.
  bool get needsMedicalClearance => answers.contains(true);

  List<String> get flaggedQuestions => [
    for (int i = 0; i < answers.length && i < parqQuestions.length; i++)
      if (answers[i]) parqQuestions[i],
  ];

  DateTime get answeredDate => DateTime.fromMillisecondsSinceEpoch(answeredAt);

  Map<String, dynamic> toMap() => {
    'answers': answers,
    'answeredAt': answeredAt,
    'version': version,
  };

  static ParQ? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final answers = [
      for (final a in (map['answers'] as List<dynamic>? ?? const [])) a == true,
    ];
    if (answers.isEmpty) return null;
    return ParQ(
      answers: answers,
      answeredAt: (map['answeredAt'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
    );
  }
}

const int parqVersion = 1;

/// As 7 perguntas do PAR-Q, em pt-BR.
const List<String> parqQuestions = [
  'Algum médico já disse que você tem algum problema de coração ou pressão '
      'alta?',
  'Você sente dor no peito quando está em repouso, nas atividades do dia a '
      'dia ou quando faz atividade física?',
  'Você perde o equilíbrio por causa de tontura ou perdeu a consciência nos '
      'últimos 12 meses?',
  'Algum médico já disse que você tem alguma outra doença crônica (além de '
      'problema de coração ou pressão alta)?',
  'Você toma remédio receitado para alguma doença crônica?',
  'Você tem (ou teve nos últimos 12 meses) algum problema nos ossos, nas '
      'articulações ou nos músculos que pode piorar com atividade física?',
  'Algum médico já disse que você só deve fazer atividade física com '
      'supervisão médica?',
];

/// Texto do aviso de responsabilidade do treino livre, aceito uma vez.
const String freeWorkoutTerms =
    'No treino livre é você quem escolhe os exercícios, as cargas e o volume. '
    'O NewFitness não avalia nem prescreve esse treino. Respeite seus '
    'limites, aqueça antes, use técnica correta e pare se sentir dor, '
    'tontura ou falta de ar. Se você tem alguma condição de saúde, procure '
    'um médico e, se possível, treine com um profissional de Educação Física.';
