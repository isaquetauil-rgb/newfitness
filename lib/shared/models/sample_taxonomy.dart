import 'equipment_item.dart';
import 'muscle_group.dart';

/// Taxonomia inicial de grupos musculares e equipamentos, usada como seed
/// (ver `ExerciseTaxonomyProvider._syncDefaults`) — mesmo espírito de
/// `sample_exercises.dart`: existe pra o app não abrir "vazio" na primeira
/// vez, mas o admin pode adicionar/editar/remover qualquer item depois pela
/// tela de administração, sem precisar mexer no código.
///
/// Padronizada na Etapa 2 da biblioteca (ver exercise_taxonomy.dart). Os IDs
/// antigos foram mantidos (ex.: 'ombro' agora se chama "Ombros",
/// 'peso_do_corpo' agora é "Peso corporal"). "Pernas" e "Braço" saíram da
/// lista, mas continuam sendo entendidos na leitura de dados antigos.
final List<MuscleGroup> sampleMuscleGroups = [
  const MuscleGroup(id: 'peito', name: 'Peito'),
  const MuscleGroup(id: 'costas', name: 'Costas'),
  const MuscleGroup(id: 'ombro', name: 'Ombros'),
  const MuscleGroup(id: 'biceps', name: 'Bíceps'),
  const MuscleGroup(id: 'triceps', name: 'Tríceps'),
  const MuscleGroup(id: 'antebraco', name: 'Antebraço'),
  const MuscleGroup(id: 'quadriceps', name: 'Quadríceps'),
  const MuscleGroup(id: 'posteriores_de_coxa', name: 'Posteriores de coxa'),
  const MuscleGroup(id: 'gluteos', name: 'Glúteos'),
  const MuscleGroup(id: 'adutores', name: 'Adutores'),
  const MuscleGroup(id: 'abdutores', name: 'Abdutores'),
  const MuscleGroup(id: 'panturrilha', name: 'Panturrilha'),
  const MuscleGroup(id: 'abdomen', name: 'Abdômen'),
  const MuscleGroup(id: 'corpo_todo', name: 'Corpo todo'),
];

final List<EquipmentItem> sampleEquipment = [
  const EquipmentItem(id: 'barra', name: 'Barra'),
  const EquipmentItem(id: 'halteres', name: 'Halteres'),
  const EquipmentItem(id: 'anilha', name: 'Anilha'),
  const EquipmentItem(id: 'polia', name: 'Polia'),
  const EquipmentItem(id: 'maquina', name: 'Máquina'),
  const EquipmentItem(id: 'smith', name: 'Smith'),
  const EquipmentItem(id: 'kettlebell', name: 'Kettlebell'),
  const EquipmentItem(id: 'elastico', name: 'Elástico'),
  const EquipmentItem(id: 'peso_do_corpo', name: 'Peso corporal'),
  const EquipmentItem(id: 'banco', name: 'Banco'),
  const EquipmentItem(id: 'caneleira', name: 'Caneleira'),
  const EquipmentItem(id: 'bola_medicinal', name: 'Bola medicinal'),
  const EquipmentItem(id: 'barra_fixa', name: 'Barra fixa'),
  const EquipmentItem(id: 'esteira_bike', name: 'Esteira'),
  const EquipmentItem(id: 'bicicleta', name: 'Bicicleta'),
  const EquipmentItem(id: 'eliptico', name: 'Elíptico'),
  const EquipmentItem(id: 'remo', name: 'Remo'),
  const EquipmentItem(id: 'escada', name: 'Escada'),
  const EquipmentItem(id: 'corda', name: 'Corda'),
  const EquipmentItem(id: 'roda_abdominal', name: 'Roda abdominal'),
];
