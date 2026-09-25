import 'equipment_item.dart';
import 'muscle_group.dart';

/// Taxonomia inicial de grupos musculares e equipamentos, usada como seed
/// (ver `ExerciseTaxonomyProvider._syncDefaults`) — mesmo espírito de
/// `sample_exercises.dart`: existe pra o app não abrir "vazio" na primeira
/// vez, mas o admin pode adicionar/editar/remover qualquer item depois pela
/// tela de administração, sem precisar mexer no código.
final List<MuscleGroup> sampleMuscleGroups = [
  const MuscleGroup(id: 'peito', name: 'Peito'),
  const MuscleGroup(id: 'costas', name: 'Costas'),
  const MuscleGroup(id: 'pernas', name: 'Pernas'),
  const MuscleGroup(id: 'ombro', name: 'Ombro'),
  const MuscleGroup(id: 'braco', name: 'Braço'),
  const MuscleGroup(id: 'abdomen', name: 'Abdômen'),
  const MuscleGroup(id: 'gluteos', name: 'Glúteos'),
  const MuscleGroup(id: 'panturrilha', name: 'Panturrilha'),
  const MuscleGroup(id: 'corpo_todo', name: 'Corpo todo'),
];

final List<EquipmentItem> sampleEquipment = [
  const EquipmentItem(id: 'barra', name: 'Barra'),
  const EquipmentItem(id: 'halteres', name: 'Halteres'),
  const EquipmentItem(id: 'maquina', name: 'Máquina'),
  const EquipmentItem(id: 'polia', name: 'Polia'),
  const EquipmentItem(id: 'peso_do_corpo', name: 'Peso do corpo'),
  const EquipmentItem(id: 'kettlebell', name: 'Kettlebell'),
  const EquipmentItem(id: 'elastico', name: 'Elástico'),
  const EquipmentItem(id: 'banco', name: 'Banco'),
  const EquipmentItem(id: 'esteira_bike', name: 'Esteira/bike'),
];
