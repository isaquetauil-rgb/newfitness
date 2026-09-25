/// Um equipamento curado (ex: "Barra", "Halteres", "Máquina") — coleção de
/// referência `equipment/{id}`, mesmo espírito de [MuscleGroup]: permite
/// cadastrar um equipamento novo sem alterar o código.
class EquipmentItem {
  final String id;
  final String name;
  final String? description;

  const EquipmentItem({required this.id, required this.name, this.description});

  factory EquipmentItem.fromMap(String id, Map<String, dynamic> map) {
    return EquipmentItem(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'description': description};
  }
}
