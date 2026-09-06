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

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.instructions = const [],
  });

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    return Exercise(
      id: id,
      name: map['name'] as String? ?? '',
      muscleGroup: map['muscleGroup'] as String? ?? '',
      equipment: map['equipment'] as String? ?? '',
      description: map['description'] as String? ?? '',
      videoUrl: map['videoUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      instructions:
          (map['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
    };
  }
}
