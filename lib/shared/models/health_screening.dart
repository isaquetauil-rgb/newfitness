/// Questionário rápido de saúde (no estilo do PAR-Q) respondido pelo aluno
/// antes de começar sozinho um treino pronto da área de saúde (idosos, pouca
/// mobilidade, postura). Qualquer "sim" bloqueia o treino e encaminha para um
/// personal ou para a equipe.
///
/// Cada resposta é gravada como um registro novo, que não pode ser editado
/// nem apagado (ver `firestore.rules`): fica a prova do que o aluno declarou.
class HealthScreening {
  const HealthScreening({
    required this.answers,
    required this.createdAt,
    this.id = '',
    this.version = healthScreeningVersion,
  });

  final String id;

  /// Uma resposta por pergunta de [healthScreeningQuestions]; `true` = sim.
  final List<bool> answers;

  /// Milissegundos desde a época.
  final int createdAt;

  /// Versão das perguntas. Se as perguntas mudarem, sobe a versão e as
  /// respostas antigas deixam de valer.
  final int version;

  /// Liberado só quando todas as respostas são "não".
  bool get cleared => !answers.contains(true);

  /// Ainda vale: mesma versão das perguntas e respondido há menos de
  /// [healthScreeningValidity].
  bool isValidAt(DateTime now) =>
      version == healthScreeningVersion &&
      answers.length == healthScreeningQuestions.length &&
      now.difference(DateTime.fromMillisecondsSinceEpoch(createdAt)) <
          healthScreeningValidity;

  /// Perguntas em que o aluno respondeu "sim".
  List<String> get flaggedQuestions => [
    for (
      int i = 0;
      i < answers.length && i < healthScreeningQuestions.length;
      i++
    )
      if (answers[i]) healthScreeningQuestions[i],
  ];

  Map<String, dynamic> toMap() => {
    'answers': answers,
    'cleared': cleared,
    'createdAt': createdAt,
    'version': version,
  };

  factory HealthScreening.fromMap(String id, Map<String, dynamic> map) =>
      HealthScreening(
        id: id,
        answers: [
          for (final a in (map['answers'] as List<dynamic>? ?? const []))
            a == true,
        ],
        createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
        version: (map['version'] as num?)?.toInt() ?? 0,
      );
}

const int healthScreeningVersion = 1;

/// Depois deste prazo o aluno responde de novo (a saúde muda).
const Duration healthScreeningValidity = Duration(days: 180);

const List<String> healthScreeningQuestions = [
  'Algum médico já disse que você tem problema no coração ou que só deve '
      'fazer exercício com acompanhamento?',
  'Você sente dor no peito, falta de ar fora do normal ou tontura quando '
      'faz esforço?',
  'Você tem dor nas articulações (joelho, quadril, ombro ou coluna) que '
      'piora com o movimento?',
  'Você fez alguma cirurgia ou teve alguma lesão nos últimos 6 meses?',
  'Você toma remédio para pressão, para o coração ou para diabetes?',
];
