/// Um grupo muscular curado (ex: "Peito", "Costas", "Pernas") — coleção de
/// referência `muscle_groups/{id}`, gerenciada pelo admin (ver
/// `AdminTaxonomyScreen`). Existir como coleção própria (em vez de string
/// solta, como era antes) é o que permite adicionar um grupo muscular novo
/// sem alterar o código: ele aparece imediatamente nos formulários de
/// exercício e nos filtros da biblioteca.
class MuscleGroup {
  final String id;
  final String name;
  final String? description;

  const MuscleGroup({required this.id, required this.name, this.description});

  factory MuscleGroup.fromMap(String id, Map<String, dynamic> map) {
    return MuscleGroup(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'description': description};
  }
}
