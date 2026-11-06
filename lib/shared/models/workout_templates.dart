import 'sample_functional_exercises.dart';
import 'training_plan.dart';

/// Prefixo de `WorkoutSource.planId` em treinos iniciados de um treino
/// pronto, para diferenciá-los dos planos prescritos por um instrutor.
const String templatePlanPrefix = 'template:';

/// Seção do treino no catálogo.
enum TemplateCategory { general, sport, care }

/// Treino pronto do catálogo do app. São sugestões gerais, sem avaliação
/// individual: um plano prescrito por personal continua em [TrainingPlan].
class WorkoutTemplate {
  final String id;
  final String title;
  final String summary;
  final String level;
  final int daysPerWeek;
  final int minutes;
  final bool isPremium;
  final TemplateCategory category;

  /// Cuidado específico deste público, mostrado antes de começar.
  final String? safetyNote;
  final List<TrainingSubWorkout> workouts;

  const WorkoutTemplate({
    required this.id,
    required this.title,
    required this.summary,
    required this.level,
    required this.daysPerWeek,
    required this.minutes,
    required this.workouts,
    this.isPremium = false,
    this.category = TemplateCategory.general,
    this.safetyNote,
  });

  /// Formato aceito por `WorkoutProvider.startFromPlan`.
  TrainingPlan toPlan(String userId) => TrainingPlan(
    id: '$templatePlanPrefix$id',
    studentUid: userId,
    instructorUid: '',
    title: title,
    workouts: workouts,
    createdAt: DateTime.now(),
  );
}

PlanExercise _ex(
  String id,
  String name,
  int sets,
  String reps, {
  int rest = 60,
  String? notes,
}) => PlanExercise(
  exerciseId: id,
  exerciseName: name,
  targetSets: sets,
  targetReps: reps,
  restSeconds: rest,
  notes: notes ?? _howTo[id],
);

/// Passo a passo dos exercícios sem vídeo, mostrado durante o treino. Quem
/// já tem biblioteca publicada não recebe esses exercícios automaticamente.
final Map<String, String> _howTo = {
  for (final exercise in sampleFunctionalExercises)
    exercise.id: exercise.instructions.join(' '),
};

final List<WorkoutTemplate> workoutTemplates = [
  WorkoutTemplate(
    id: 'primeiros_passos',
    title: 'Primeiros passos',
    summary: 'Corpo inteiro, nas máquinas, para pegar o ritmo.',
    level: 'Iniciante',
    daysPerWeek: 3,
    minutes: 40,
    workouts: [
      TrainingSubWorkout(
        label: 'Corpo inteiro',
        exercises: [
          _ex('leg_press', 'Leg press 45°', 3, '12'),
          _ex('machine_chest_press', 'Supino na máquina', 3, '12'),
          _ex('lat_pulldown', 'Puxada frontal', 3, '12'),
          _ex('lateral_raise', 'Elevação lateral', 2, '12'),
          _ex('plank', 'Prancha abdominal', 3, '30 s', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'em_casa',
    title: 'Em casa',
    summary: 'Sem academia, usando o peso do corpo.',
    level: 'Iniciante',
    daysPerWeek: 3,
    minutes: 25,
    workouts: [
      TrainingSubWorkout(
        label: 'Circuito',
        exercises: [
          _ex('push_up', 'Flexão de braço', 3, '8-12', rest: 45),
          _ex(
            'lunge',
            'Afundo',
            3,
            '10',
            rest: 45,
            notes: 'Pode fazer sem halteres.',
          ),
          _ex('crunch', 'Abdominal supra', 3, '15', rest: 30),
          _ex('plank', 'Prancha abdominal', 3, '30 s', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'duas_divisoes',
    title: 'Treino A e B',
    summary: 'Superior e inferior, alternando os dias.',
    level: 'Iniciante',
    daysPerWeek: 4,
    minutes: 45,
    workouts: [
      TrainingSubWorkout(
        label: 'Treino A',
        exercises: [
          _ex('machine_chest_press', 'Supino na máquina', 3, '10-12'),
          _ex('lat_pulldown', 'Puxada frontal', 3, '10-12'),
          _ex('lateral_raise', 'Elevação lateral', 3, '12'),
          _ex('bicep_curl', 'Rosca direta', 2, '12'),
          _ex('tricep_extension', 'Tríceps testa', 2, '12'),
        ],
      ),
      TrainingSubWorkout(
        label: 'Treino B',
        exercises: [
          _ex('leg_press', 'Leg press 45°', 3, '10-12'),
          _ex('leg_curl', 'Mesa flexora', 3, '12'),
          _ex('leg_extension', 'Cadeira extensora', 3, '12'),
          _ex('calf_raise', 'Panturrilha em pé', 3, '15', rest: 45),
          _ex('crunch', 'Abdominal supra', 3, '15', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'hipertrofia_abc',
    title: 'Hipertrofia ABC',
    summary: 'Três divisões com mais volume por grupo muscular.',
    level: 'Intermediário',
    daysPerWeek: 5,
    minutes: 60,
    isPremium: true,
    workouts: [
      TrainingSubWorkout(
        label: 'A: peito, ombro e tríceps',
        exercises: [
          _ex('bench_press', 'Supino reto', 4, '8-10', rest: 90),
          _ex(
            'incline_dumbbell_press',
            'Supino inclinado com halteres',
            3,
            '10-12',
            rest: 75,
          ),
          _ex('shoulder_press', 'Desenvolvimento militar', 3, '8-10', rest: 90),
          _ex('lateral_raise', 'Elevação lateral', 3, '12-15'),
          _ex('tricep_extension', 'Tríceps testa', 3, '10-12'),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: costas e bíceps',
        exercises: [
          _ex('lat_pulldown', 'Puxada frontal', 4, '8-10', rest: 75),
          _ex('bent_over_row', 'Remada curvada', 4, '8-10', rest: 90),
          _ex('pull_up', 'Barra fixa', 3, 'Até a falha técnica', rest: 90),
          _ex('bicep_curl', 'Rosca direta', 3, '10-12'),
        ],
      ),
      TrainingSubWorkout(
        label: 'C: pernas e abdômen',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '8-10', rest: 120),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '10',
            rest: 90,
          ),
          _ex('leg_press', 'Leg press 45°', 3, '12', rest: 75),
          _ex('calf_raise', 'Panturrilha em pé', 4, '15', rest: 45),
          _ex('plank', 'Prancha abdominal', 3, '45 s', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'forca_base',
    title: 'Força na base',
    summary: 'Poucas repetições nos exercícios principais.',
    level: 'Intermediário',
    daysPerWeek: 3,
    minutes: 60,
    isPremium: true,
    workouts: [
      TrainingSubWorkout(
        label: 'Dia 1',
        exercises: [
          _ex('squat', 'Agachamento livre', 5, '5', rest: 150),
          _ex('bench_press', 'Supino reto', 5, '5', rest: 150),
          _ex('bent_over_row', 'Remada curvada', 3, '8', rest: 90),
        ],
      ),
      TrainingSubWorkout(
        label: 'Dia 2',
        exercises: [
          _ex('deadlift', 'Levantamento terra', 3, '5', rest: 180),
          _ex('shoulder_press', 'Desenvolvimento militar', 5, '5', rest: 150),
          _ex('pull_up', 'Barra fixa', 3, 'Até a falha técnica', rest: 90),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'gluteos_pernas',
    title: 'Glúteos e pernas',
    summary: 'Foco na parte inferior, duas vezes por semana.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    workouts: [
      TrainingSubWorkout(
        label: 'Inferiores',
        exercises: [
          _ex('hip_thrust', 'Elevação pélvica', 4, '10-12', rest: 90),
          _ex('squat', 'Agachamento livre', 4, '8-10', rest: 120),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '10-12',
            rest: 90,
          ),
          _ex('lunge', 'Afundo', 3, '12', rest: 75),
          _ex('leg_curl', 'Mesa flexora', 3, '12-15'),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'futebol',
    title: 'Futebol',
    summary: 'Força, arrancada e mudança de direção para jogar melhor.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.sport,
    workouts: [
      TrainingSubWorkout(
        label: 'Força',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '6-8', rest: 120),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '8',
            rest: 90,
          ),
          _ex('side_lunge', 'Afundo lateral', 3, '8 por lado'),
          _ex('nordic_curl', 'Flexão nórdica assistida', 3, '4-6', rest: 90),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Potência',
        exercises: [
          _ex('squat_jump', 'Agachamento com salto', 4, '5', rest: 90),
          _ex('lateral_bound', 'Salto lateral', 3, '6 por lado', rest: 75),
          _ex('hip_thrust', 'Elevação pélvica', 3, '8', rest: 90),
          _ex('calf_raise', 'Panturrilha em pé', 3, '12', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'jiu_jitsu',
    title: 'Jiu-jitsu',
    summary: 'Pegada, quadril e abdômen para render no tatame.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.sport,
    workouts: [
      TrainingSubWorkout(
        label: 'Força e pegada',
        exercises: [
          _ex('deadlift', 'Levantamento terra', 4, '5', rest: 150),
          _ex('pull_up', 'Barra fixa', 4, 'Até a falha técnica', rest: 90),
          _ex('bent_over_row', 'Remada curvada', 3, '8', rest: 90),
          _ex('dead_hang', 'Suspensão na barra', 3, '30 s', rest: 60),
          _ex('farmer_walk', 'Caminhada do fazendeiro', 3, '30 m', rest: 75),
        ],
      ),
      TrainingSubWorkout(
        label: 'Quadril e core',
        exercises: [
          _ex('kettlebell_swing', 'Balanço com kettlebell', 4, '12', rest: 75),
          _ex('hip_escape', 'Fuga de quadril no chão', 3, '10 por lado'),
          _ex('hip_90_90', 'Mobilidade de quadril 90/90', 3, '8 por lado'),
          _ex('russian_twist', 'Rotação russa', 3, '20', rest: 45),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'corrida',
    title: 'Corrida',
    summary: 'Força e mobilidade para correr com mais estabilidade.',
    level: 'Iniciante',
    daysPerWeek: 2,
    minutes: 40,
    isPremium: true,
    category: TemplateCategory.sport,
    safetyNote:
        'Faça em dias sem treino forte de corrida. Dor que muda sua '
        'passada é motivo para parar e procurar avaliação.',
    workouts: [
      TrainingSubWorkout(
        label: 'Força para correr',
        exercises: [
          _ex('step_up', 'Subida no degrau', 3, '10 por lado'),
          _ex('lunge', 'Afundo', 3, '10 por lado'),
          _ex('glute_bridge', 'Ponte de glúteos', 3, '12', rest: 45),
          _ex('calf_raise', 'Panturrilha em pé', 3, '15', rest: 45),
          _ex(
            'ankle_mobility',
            'Mobilidade de tornozelo na parede',
            2,
            '10 por lado',
            rest: 30,
          ),
          _ex('plank', 'Prancha abdominal', 3, '30 s', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'volei',
    title: 'Vôlei',
    summary: 'Salto, ombros fortes e aterrissagem segura.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.sport,
    workouts: [
      TrainingSubWorkout(
        label: 'Salto',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '6', rest: 120),
          _ex('squat_jump', 'Agachamento com salto', 4, '5', rest: 90),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '8',
            rest: 90,
          ),
          _ex('calf_raise', 'Panturrilha em pé', 3, '12', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Ombros e core',
        exercises: [
          _ex('lat_pulldown', 'Puxada frontal', 3, '10', rest: 75),
          _ex(
            'band_external_rotation',
            'Rotação externa com elástico',
            3,
            '12 por lado',
            rest: 45,
          ),
          _ex('band_pull_apart', 'Abertura com elástico', 3, '15', rest: 45),
          _ex(
            'thoracic_rotation',
            'Rotação de tronco em quatro apoios',
            2,
            '8 por lado',
            rest: 30,
          ),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'futevolei',
    title: 'Futevôlei',
    summary: 'Pernas, tornozelos e quadris preparados para a areia.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 45,
    isPremium: true,
    category: TemplateCategory.sport,
    workouts: [
      TrainingSubWorkout(
        label: 'Pernas e salto',
        exercises: [
          _ex('squat_jump', 'Agachamento com salto', 4, '5', rest: 90),
          _ex('lateral_bound', 'Salto lateral', 3, '6 por lado', rest: 75),
          _ex('side_lunge', 'Afundo lateral', 3, '8 por lado'),
          _ex('calf_raise', 'Panturrilha em pé', 3, '15', rest: 45),
          _ex(
            'single_leg_balance',
            'Equilíbrio em um pé',
            3,
            '30 s por lado',
            rest: 30,
          ),
        ],
      ),
      TrainingSubWorkout(
        label: 'Quadril e core',
        exercises: [
          _ex('hip_thrust', 'Elevação pélvica', 3, '10', rest: 90),
          _ex('hip_90_90', 'Mobilidade de quadril 90/90', 3, '8 por lado'),
          _ex(
            'ankle_mobility',
            'Mobilidade de tornozelo na parede',
            2,
            '10 por lado',
            rest: 30,
          ),
          _ex('russian_twist', 'Rotação russa', 3, '20', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'pouca_mobilidade',
    title: 'Pouca mobilidade',
    summary: 'Movimentos suaves para soltar quadril, costas e tornozelos.',
    level: 'Iniciante',
    daysPerWeek: 3,
    minutes: 20,
    isPremium: true,
    category: TemplateCategory.care,
    safetyNote:
        'Vá até onde não causar dor. Limitação por lesão ou cirurgia '
        'precisa de orientação de um profissional de saúde.',
    workouts: [
      TrainingSubWorkout(
        label: 'Rotina de mobilidade',
        exercises: [
          _ex('cat_cow', 'Gato e camelo', 2, '10', rest: 20),
          _ex(
            'thoracic_rotation',
            'Rotação de tronco em quatro apoios',
            2,
            '8 por lado',
            rest: 20,
          ),
          _ex(
            'hip_90_90',
            'Mobilidade de quadril 90/90',
            2,
            '8 por lado',
            rest: 20,
          ),
          _ex(
            'ankle_mobility',
            'Mobilidade de tornozelo na parede',
            2,
            '10 por lado',
            rest: 20,
          ),
          _ex('glute_bridge', 'Ponte de glúteos', 2, '10', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'idosos',
    title: 'Pessoas idosas',
    summary: 'Força e equilíbrio para o dia a dia, com apoio e sem pressa.',
    level: 'Iniciante',
    daysPerWeek: 2,
    minutes: 30,
    isPremium: true,
    category: TemplateCategory.care,
    safetyNote:
        'Antes de começar, fale com seu médico. Faça perto de um apoio '
        'firme, de preferência acompanhado. Tontura, dor no peito ou falta '
        'de ar: pare e procure atendimento.',
    workouts: [
      TrainingSubWorkout(
        label: 'Força e equilíbrio',
        exercises: [
          _ex('sit_to_stand', 'Sentar e levantar da cadeira', 2, '8', rest: 90),
          _ex('wall_push_up', 'Flexão na parede', 2, '8', rest: 90),
          _ex(
            'single_leg_balance',
            'Equilíbrio em um pé',
            2,
            '15 s por lado',
            rest: 60,
          ),
          _ex(
            'heel_toe_walk',
            'Caminhada calcanhar e ponta',
            2,
            '10 passos',
            rest: 60,
          ),
          _ex('glute_bridge', 'Ponte de glúteos', 2, '8', rest: 60),
        ],
      ),
    ],
  ),
];
