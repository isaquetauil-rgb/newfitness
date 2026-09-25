/// Níveis de dificuldade aceitos em [Exercise.difficultyLevel] — usados tanto
/// no formulário de cadastro (chips) quanto no cálculo de semelhança em
/// `exercise_similarity.dart`.
const List<String> exerciseDifficultyLevels = [
  'iniciante',
  'intermediario',
  'avancado',
];

String exerciseDifficultyLabel(String level) {
  switch (level) {
    case 'iniciante':
      return 'Iniciante';
    case 'intermediario':
      return 'Intermediário';
    case 'avancado':
      return 'Avançado';
    default:
      return 'Não informado';
  }
}

/// Categoria do exercício — molda quais campos de prescrição fazem sentido
/// (um exercício "cardio" usa distância/duração/calorias; um "forca" usa
/// séries/reps/carga).
const List<String> exerciseCategories = [
  'forca',
  'cardio',
  'mobilidade',
  'alongamento',
  'hiit',
];

String exerciseCategoryLabel(String category) {
  switch (category) {
    case 'forca':
      return 'Força';
    case 'cardio':
      return 'Cardio';
    case 'mobilidade':
      return 'Mobilidade';
    case 'alongamento':
      return 'Alongamento';
    case 'hiit':
      return 'HIIT';
    default:
      return 'Não informado';
  }
}

/// Unidade da carga prescrita (ver [Exercise.defaultLoad]).
const List<String> exerciseLoadUnits = ['kg', 'lb', 'peso do corpo', 'nenhuma'];

/// Cadeia cinética do movimento — cadeia fechada (pé/mão fixos, ex:
/// agachamento, flexão) tende a ser mais amigável a lesões articulares que
/// cadeia aberta (extremidade livre, ex: cadeira extensora, rosca direta).
const List<String> exerciseKineticChains = ['aberta', 'fechada'];

/// Sugestões de padrão de movimento — não é uma lista fechada (o campo é
/// texto livre, pra não travar a cadastro de um exercício fora do comum),
/// mas usar um destes valores é o que faz o exercício entrar bem no cálculo
/// de semelhança (dois exercícios com o mesmo padrão pontuam alto).
const List<String> exerciseMovementPatternSuggestions = [
  'Empurrar horizontal',
  'Empurrar vertical',
  'Puxar horizontal',
  'Puxar vertical',
  'Agachamento',
  'Dobradiça de quadril',
  'Isolamento',
  'Core/estabilização',
];

/// Sugestões de objetivo — mesmo espírito de
/// [exerciseMovementPatternSuggestions]: texto livre, lista só para ajudar a
/// digitação e manter os valores consistentes entre exercícios.
const List<String> exerciseObjectiveSuggestions = [
  'hipertrofia',
  'forca',
  'resistencia',
  'mobilidade',
  'emagrecimento',
  'reabilitacao',
];

/// Representa um exercício disponível na biblioteca do app,
/// incluindo o vídeo que ensina a execução do movimento.
class Exercise {
  final String id;
  final String name;
  final String muscleGroup; // ex: "Peito", "Costas", "Pernas", "Ombro"...
  final String equipment; // ex: "Barra", "Halteres", "Peso do corpo"
  final String description;
  final String videoUrl; // URL do vídeo (mp4 direto ou link externo)
  final String? thumbnailUrl;
  final List<String> instructions; // passo a passo do movimento

  /// Nome pelo qual o exercício também é conhecido (ex: "Stiff" para
  /// "Levantamento terra romeno") — usado na busca, além do [name].
  final String alternateName;

  /// "forca" | "cardio" | "mobilidade" | "alongamento" | "hiit" (ver
  /// [exerciseCategories]) — diferente de [objectives] (o objetivo de
  /// treino, ex: hipertrofia): categoria é o TIPO de exercício.
  final String category;

  /// Dicas de execução correta (postura, respiração, pontos de atenção) —
  /// complementar ao passo a passo em [instructions].
  final String executionNotes;

  /// Erros comuns cometidos ao executar o movimento.
  final List<String> commonMistakes;

  /// Cuidados e contraindicações (ex: "evitar em caso de dor lombar aguda").
  final String careNotes;

  /// Prescrição padrão sugerida — usada para pré-preencher o formulário do
  /// instrutor ao montar uma ficha (ver `PlanEditorScreen`), mas cada plano
  /// pode sobrescrever livremente (`PlanExercise.targetSets` etc.).
  final int? defaultSets;
  final String defaultReps; // texto livre, ex: "8-12"
  final int? executionTempoSeconds; // ex: exercício isométrico/prancha
  final int? defaultRestSeconds;
  final double? defaultLoad;
  final String loadUnit; // um de [exerciseLoadUnits], ou '' se não aplicável

  /// Liga os campos de distância/duração no registro do treino — usado por
  /// exercícios de cardio (esteira, corrida, bike).
  final bool tracksDistance;
  final double? defaultDistanceMeters;
  final bool tracksDuration;
  final int? defaultDurationSeconds;
  final double? estimatedCaloriesPerMinute;

  /// Imagens estáticas do movimento (além do [thumbnailUrl], que é usado
  /// como miniatura em listas) — ex: fotos de início/fim do movimento.
  final List<String> imageUrls;

  /// Tags livres para busca/filtro (ex: "peito superior", "compound",
  /// "iniciante-friendly") — complementam os campos estruturados.
  final List<String> searchTags;

  /// true quando o exercício é feito um lado do corpo por vez (ex: afundo,
  /// rosca alternada) — relevante pra registrar carga/reps por lado.
  final bool isUnilateral;

  /// "aberta" | "fechada" (ver [exerciseKineticChains]).
  final String kineticChain;

  /// Músculos secundários ativados além do [muscleGroup] principal (ex: um
  /// supino reto tem [muscleGroup] "Peito" e pode listar "Tríceps" e
  /// "Ombro" aqui) — usado para encontrar variações com estímulo parecido
  /// mesmo quando o grupo muscular principal não bate 100%.
  final List<String> secondaryMuscles;

  /// Padrão biomecânico do movimento (ver
  /// [exerciseMovementPatternSuggestions]) — o critério mais forte de
  /// equivalência entre dois exercícios: um supino reto com halteres é uma
  /// alternativa muito melhor a um supino reto com barra do que um
  /// crucifixo, mesmo os três sendo "Peito".
  final String movementPattern;

  /// Nível de dificuldade — um dos [exerciseDifficultyLevels], ou vazio
  /// quando ainda não classificado.
  final String difficultyLevel;

  /// Objetivo(s) do exercício (ver [exerciseObjectiveSuggestions]).
  final List<String> objectives;

  /// Ids de outros exercícios que são **variações** deste (mesmo padrão de
  /// movimento, equipamento ou ângulo diferente — ex: "Supino reto" →
  /// "Supino inclinado com halteres"). Diferente de
  /// [alternativeExerciseIds] (substitutos de objetivo/músculo parecido,
  /// não necessariamente o mesmo movimento) — ver
  /// `findExerciseVariations` vs `findExerciseAlternatives` em
  /// `exercise_similarity.dart`.
  final List<String> variationExerciseIds;

  /// Ids de outros exercícios (desta coleção `exercises` ou de
  /// `custom_exercises` de algum instrutor) curados manualmente como
  /// substitutos diretos — por um admin, um instrutor, ou futuramente por
  /// uma IA. Tem prioridade sobre o cálculo automático de semelhança em
  /// `findExerciseAlternatives` (ver
  /// `lib/features/exercises/logic/exercise_similarity.dart`), mas não é
  /// obrigatório: um exercício sem nenhuma curadoria ainda participa
  /// normalmente do cálculo automático baseado nos campos acima.
  final List<String> alternativeExerciseIds;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.instructions = const [],
    this.alternateName = '',
    this.category = '',
    this.executionNotes = '',
    this.commonMistakes = const [],
    this.careNotes = '',
    this.defaultSets,
    this.defaultReps = '',
    this.executionTempoSeconds,
    this.defaultRestSeconds,
    this.defaultLoad,
    this.loadUnit = '',
    this.tracksDistance = false,
    this.defaultDistanceMeters,
    this.tracksDuration = false,
    this.defaultDurationSeconds,
    this.estimatedCaloriesPerMinute,
    this.imageUrls = const [],
    this.searchTags = const [],
    this.isUnilateral = false,
    this.kineticChain = '',
    this.secondaryMuscles = const [],
    this.movementPattern = '',
    this.difficultyLevel = '',
    this.objectives = const [],
    this.variationExerciseIds = const [],
    this.alternativeExerciseIds = const [],
  });

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    List<String> stringList(String key) =>
        (map[key] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [];

    return Exercise(
      id: id,
      name: map['name'] as String? ?? '',
      muscleGroup: map['muscleGroup'] as String? ?? '',
      equipment: map['equipment'] as String? ?? '',
      description: map['description'] as String? ?? '',
      videoUrl: map['videoUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      instructions: stringList('instructions'),
      alternateName: map['alternateName'] as String? ?? '',
      category: map['category'] as String? ?? '',
      executionNotes: map['executionNotes'] as String? ?? '',
      commonMistakes: stringList('commonMistakes'),
      careNotes: map['careNotes'] as String? ?? '',
      defaultSets: (map['defaultSets'] as num?)?.toInt(),
      defaultReps: map['defaultReps'] as String? ?? '',
      executionTempoSeconds: (map['executionTempoSeconds'] as num?)?.toInt(),
      defaultRestSeconds: (map['defaultRestSeconds'] as num?)?.toInt(),
      defaultLoad: (map['defaultLoad'] as num?)?.toDouble(),
      loadUnit: map['loadUnit'] as String? ?? '',
      tracksDistance: map['tracksDistance'] as bool? ?? false,
      defaultDistanceMeters: (map['defaultDistanceMeters'] as num?)?.toDouble(),
      tracksDuration: map['tracksDuration'] as bool? ?? false,
      defaultDurationSeconds: (map['defaultDurationSeconds'] as num?)?.toInt(),
      estimatedCaloriesPerMinute: (map['estimatedCaloriesPerMinute'] as num?)
          ?.toDouble(),
      imageUrls: stringList('imageUrls'),
      searchTags: stringList('searchTags'),
      isUnilateral: map['isUnilateral'] as bool? ?? false,
      kineticChain: map['kineticChain'] as String? ?? '',
      secondaryMuscles: stringList('secondaryMuscles'),
      movementPattern: map['movementPattern'] as String? ?? '',
      difficultyLevel: map['difficultyLevel'] as String? ?? '',
      objectives: stringList('objectives'),
      variationExerciseIds: stringList('variationExerciseIds'),
      alternativeExerciseIds: stringList('alternativeExerciseIds'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'instructions': instructions,
      'alternateName': alternateName,
      'category': category,
      'executionNotes': executionNotes,
      'commonMistakes': commonMistakes,
      'careNotes': careNotes,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'executionTempoSeconds': executionTempoSeconds,
      'defaultRestSeconds': defaultRestSeconds,
      'defaultLoad': defaultLoad,
      'loadUnit': loadUnit,
      'tracksDistance': tracksDistance,
      'defaultDistanceMeters': defaultDistanceMeters,
      'tracksDuration': tracksDuration,
      'defaultDurationSeconds': defaultDurationSeconds,
      'estimatedCaloriesPerMinute': estimatedCaloriesPerMinute,
      'imageUrls': imageUrls,
      'searchTags': searchTags,
      'isUnilateral': isUnilateral,
      'kineticChain': kineticChain,
      'secondaryMuscles': secondaryMuscles,
      'movementPattern': movementPattern,
      'difficultyLevel': difficultyLevel,
      'objectives': objectives,
      'variationExerciseIds': variationExerciseIds,
      'alternativeExerciseIds': alternativeExerciseIds,
    };
  }
}
