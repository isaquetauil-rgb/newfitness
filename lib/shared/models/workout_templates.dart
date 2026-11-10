import 'sample_functional_exercises.dart';
import 'training_plan.dart';

/// Prefixo de `WorkoutSource.planId` em treinos iniciados de um treino
/// pronto, para diferenciá-los dos planos prescritos por um instrutor.
const String templatePlanPrefix = 'template:';

/// Seção do treino no catálogo.
enum TemplateCategory { general, sport, fight, care }

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

  /// Aquecimento antes da parte principal.
  final List<String> warmUp;

  /// Como aumentar a dificuldade ao longo das semanas.
  final String progression;
  final List<TrainingSubWorkout> workouts;

  const WorkoutTemplate({
    required this.id,
    required this.title,
    required this.summary,
    required this.level,
    required this.daysPerWeek,
    required this.minutes,
    required this.workouts,
    required this.warmUp,
    required this.progression,
    this.isPremium = false,
    this.category = TemplateCategory.general,
    this.safetyNote,
  });

  /// Treinos da área de saúde: o aluno responde o questionário de saúde
  /// antes de começar sozinho (ver `HealthScreening`).
  bool get needsHealthScreening => category == TemplateCategory.care;

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

/// Passo a passo dos exercícios funcionais, mostrado durante o treino para
/// quem ainda não tem esses exercícios na biblioteca publicada.
final Map<String, String> _howTo = {
  for (final exercise in sampleFunctionalExercises)
    exercise.id: exercise.instructions.join(' '),
};

const _rir2 = 'Pare com cerca de 2 repetições sobrando.';
const _explosive =
    'Rápido e explosivo, com descanso completo. Pare se perder a técnica.';

final List<WorkoutTemplate> workoutTemplates = [
  // ---- Grátis ----
  WorkoutTemplate(
    id: 'primeiros_passos',
    title: 'Primeiros passos',
    summary: 'Corpo inteiro nas máquinas, para aprender os movimentos.',
    level: 'Iniciante',
    daysPerWeek: 3,
    minutes: 40,
    warmUp: [
      '5 min de bicicleta ou esteira em ritmo leve.',
      'Uma série leve de 10 repetições do primeiro exercício.',
    ],
    progression:
        'Quando fizer todas as séries com as repetições indicadas e ainda '
        'sobrar fôlego, aumente um pouco a carga na semana seguinte.',
    workouts: [
      TrainingSubWorkout(
        label: 'Corpo inteiro',
        exercises: [
          _ex('leg_press', 'Leg press 45°', 3, '10-12', notes: _rir2),
          _ex(
            'machine_chest_press',
            'Supino na máquina',
            3,
            '10-12',
            notes: _rir2,
          ),
          _ex('lat_pulldown', 'Puxada frontal', 3, '10-12', notes: _rir2),
          _ex('leg_curl', 'Mesa flexora', 2, '12'),
          _ex('lateral_raise', 'Elevação lateral', 2, '12-15'),
          _ex('plank', 'Prancha abdominal', 3, '20-30 s', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'em_casa',
    title: 'Em casa',
    summary: 'Sem academia e sem equipamento, só com o peso do corpo.',
    level: 'Iniciante',
    daysPerWeek: 3,
    minutes: 25,
    warmUp: [
      '2 min de polichinelo ou marcha no lugar.',
      '10 rotações de braços.',
    ],
    progression:
        'Primeiro aumente as repetições. Depois, diminua o descanso entre os '
        'exercícios em 10 s por semana.',
    workouts: [
      TrainingSubWorkout(
        label: 'Circuito',
        exercises: [
          _ex(
            'sit_to_stand',
            'Sentar e levantar da cadeira',
            3,
            '12-15',
            rest: 45,
          ),
          _ex(
            'push_up',
            'Flexão de braço',
            3,
            '6-12',
            rest: 45,
            notes: 'Se ficar pesado, apoie os joelhos ou as mãos na parede.',
          ),
          _ex('glute_bridge', 'Ponte de glúteos', 3, '15', rest: 30),
          _ex('mountain_climber', 'Escalador', 3, '30 s', rest: 30),
          _ex('plank', 'Prancha abdominal', 3, '30 s', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'duas_divisoes',
    title: 'Treino A e B',
    summary: 'Superior e inferior em dias alternados, para ganhar massa.',
    level: 'Iniciante',
    daysPerWeek: 4,
    minutes: 45,
    warmUp: [
      '5 min de cardio leve.',
      'Uma série leve do primeiro exercício de cada treino.',
    ],
    progression:
        'Use a faixa de repetições: quando chegar no topo em todas as '
        'séries, aumente a carga e volte para o início da faixa.',
    workouts: [
      TrainingSubWorkout(
        label: 'Treino A',
        exercises: [
          _ex(
            'machine_chest_press',
            'Supino na máquina',
            3,
            '8-12',
            rest: 90,
            notes: _rir2,
          ),
          _ex(
            'lat_pulldown',
            'Puxada frontal',
            3,
            '8-12',
            rest: 90,
            notes: _rir2,
          ),
          _ex(
            'dumbbell_bench_press',
            'Supino reto com halteres',
            2,
            '10-12',
            rest: 75,
          ),
          _ex('lateral_raise', 'Elevação lateral', 3, '12-15'),
          _ex('bicep_curl', 'Rosca direta', 2, '10-12'),
          _ex('tricep_extension', 'Tríceps testa', 2, '10-12'),
        ],
      ),
      TrainingSubWorkout(
        label: 'Treino B',
        exercises: [
          _ex('leg_press', 'Leg press 45°', 3, '8-12', rest: 90, notes: _rir2),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '10',
            rest: 90,
          ),
          _ex('leg_extension', 'Cadeira extensora', 2, '12-15'),
          _ex('leg_curl', 'Mesa flexora', 2, '12-15'),
          _ex('calf_raise', 'Panturrilha em pé', 3, '12-15', rest: 45),
          _ex('crunch', 'Abdominal supra', 3, '15', rest: 45),
        ],
      ),
    ],
  ),

  // ---- Premium: academia ----
  WorkoutTemplate(
    id: 'hipertrofia_abc',
    title: 'Hipertrofia ABC',
    summary: 'Três divisões com mais volume por grupo muscular.',
    level: 'Intermediário',
    daysPerWeek: 5,
    minutes: 60,
    isPremium: true,
    warmUp: [
      '5 min de cardio leve.',
      'Duas séries de aproximação no primeiro exercício: 50% e 70% da carga.',
    ],
    progression:
        'Some uma repetição por semana em cada série. Ao chegar ao topo da '
        'faixa, aumente a carga. A cada 6 semanas, faça uma semana leve.',
    workouts: [
      TrainingSubWorkout(
        label: 'A: peito, ombro e tríceps',
        exercises: [
          _ex('bench_press', 'Supino reto', 4, '6-8', rest: 120, notes: _rir2),
          _ex(
            'incline_dumbbell_press',
            'Supino inclinado com halteres',
            3,
            '8-10',
            rest: 90,
          ),
          _ex('shoulder_press', 'Desenvolvimento militar', 3, '8-10', rest: 90),
          _ex('lateral_raise', 'Elevação lateral', 4, '12-15', rest: 45),
          _ex('tricep_extension', 'Tríceps testa', 3, '10-12'),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: costas e bíceps',
        exercises: [
          _ex(
            'pull_up',
            'Barra fixa',
            4,
            '5-8',
            rest: 120,
            notes: 'Sem conseguir ainda? Troque por puxada frontal.',
          ),
          _ex(
            'bent_over_row',
            'Remada curvada',
            4,
            '8-10',
            rest: 90,
            notes: _rir2,
          ),
          _ex('lat_pulldown', 'Puxada frontal', 3, '10-12', rest: 75),
          _ex('band_pull_apart', 'Abertura com elástico', 2, '15-20', rest: 45),
          _ex('bicep_curl', 'Rosca direta', 3, '10-12'),
        ],
      ),
      TrainingSubWorkout(
        label: 'C: pernas e abdômen',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '6-8', rest: 150, notes: _rir2),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '8-10',
            rest: 120,
          ),
          _ex('leg_press', 'Leg press 45°', 3, '10-12', rest: 90),
          _ex('leg_curl', 'Mesa flexora', 3, '10-12'),
          _ex('calf_raise', 'Panturrilha em pé', 4, '10-15', rest: 45),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'forca_base',
    title: 'Força na base',
    summary: 'Poucas repetições nos levantamentos principais.',
    level: 'Intermediário',
    daysPerWeek: 3,
    minutes: 60,
    isPremium: true,
    warmUp: [
      '5 min de cardio leve e mobilidade de quadril 90/90.',
      'Séries de aproximação crescentes até a carga do dia.',
    ],
    progression:
        'Treinos A e B alternados. Se completar todas as séries com boa '
        'técnica, some 2,5 kg nos levantamentos de pernas e 1 a 2 kg nos de '
        'tronco no treino seguinte.',
    workouts: [
      TrainingSubWorkout(
        label: 'Treino A',
        exercises: [
          _ex('squat', 'Agachamento livre', 5, '5', rest: 180),
          _ex('bench_press', 'Supino reto', 5, '5', rest: 180),
          _ex('bent_over_row', 'Remada curvada', 3, '8', rest: 90),
          _ex('farmer_walk', 'Caminhada do fazendeiro', 3, '30 m', rest: 90),
        ],
      ),
      TrainingSubWorkout(
        label: 'Treino B',
        exercises: [
          _ex('deadlift', 'Levantamento terra', 3, '5', rest: 180),
          _ex('shoulder_press', 'Desenvolvimento militar', 5, '5', rest: 150),
          _ex('pull_up', 'Barra fixa', 3, '5-8', rest: 120),
          _ex('plank', 'Prancha abdominal', 3, '45 s', rest: 45),
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
    minutes: 55,
    isPremium: true,
    warmUp: [
      '5 min de bicicleta.',
      'Ponte de glúteos: 2 x 15, sem carga.',
      'Mobilidade de quadril 90/90: 1 x 8 por lado.',
    ],
    progression:
        'Aumente a carga da elevação pélvica e do agachamento quando chegar '
        'ao topo da faixa. Mantenha 1 a 2 dias de intervalo entre os treinos.',
    workouts: [
      TrainingSubWorkout(
        label: 'Inferiores',
        exercises: [
          _ex(
            'hip_thrust',
            'Elevação pélvica',
            4,
            '8-12',
            rest: 90,
            notes: 'Segure 1 s no alto, com o queixo para baixo.',
          ),
          _ex('squat', 'Agachamento livre', 4, '6-10', rest: 150),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '8-10',
            rest: 120,
          ),
          _ex('side_lunge', 'Afundo lateral', 3, '10 por lado', rest: 75),
          _ex('step_up', 'Subida no degrau', 3, '10 por lado', rest: 75),
          _ex('leg_curl', 'Mesa flexora', 3, '12-15'),
        ],
      ),
    ],
  ),

  WorkoutTemplate(
    id: 'fisiculturismo_masculino',
    title: 'Fisiculturismo masculino',
    summary: 'Cinco dias, um grupo muscular por dia, com alto volume.',
    level: 'Avançado',
    daysPerWeek: 5,
    minutes: 70,
    isPremium: true,
    warmUp: [
      '5 min de cardio leve.',
      'Duas séries de aproximação no primeiro exercício do dia.',
    ],
    progression:
        'Aumente a carga ou as repetições a cada semana, sempre com a mesma '
        'técnica. A cada 5 a 6 semanas, faça uma semana com metade das '
        'séries para recuperar.',
    workouts: [
      TrainingSubWorkout(
        label: 'Peito',
        exercises: [
          _ex('bench_press', 'Supino reto', 4, '6-8', rest: 150, notes: _rir2),
          _ex(
            'incline_dumbbell_press',
            'Supino inclinado com halteres',
            4,
            '8-10',
            rest: 120,
          ),
          _ex('pec_deck', 'Voador (peck deck)', 3, '10-12', rest: 75),
          _ex(
            'cable_crossover',
            'Crossover na polia',
            3,
            '12-15',
            rest: 60,
            notes: 'Segure 1 s com as mãos juntas.',
          ),
          _ex('push_up', 'Flexão de braço', 2, 'Até a falha técnica', rest: 60),
        ],
      ),
      TrainingSubWorkout(
        label: 'Costas',
        exercises: [
          _ex('pull_up', 'Barra fixa', 4, '6-10', rest: 120),
          _ex(
            'bent_over_row',
            'Remada curvada',
            4,
            '8-10',
            rest: 120,
            notes: _rir2,
          ),
          _ex('lat_pulldown', 'Puxada frontal', 3, '10-12', rest: 90),
          _ex(
            'seated_cable_row',
            'Remada baixa na polia',
            3,
            '10-12',
            rest: 90,
          ),
          _ex(
            'dumbbell_row',
            'Remada unilateral com halter',
            3,
            '10 por lado',
            rest: 75,
          ),
        ],
      ),
      TrainingSubWorkout(
        label: 'Pernas',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '6-8', rest: 180, notes: _rir2),
          _ex('hack_squat', 'Agachamento no hack', 3, '8-10', rest: 120),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            4,
            '8-10',
            rest: 120,
          ),
          _ex('leg_extension', 'Cadeira extensora', 3, '12-15', rest: 60),
          _ex('leg_curl', 'Mesa flexora', 3, '10-12', rest: 60),
          _ex('calf_raise', 'Panturrilha em pé', 4, '10-12', rest: 45),
          _ex('seated_calf_raise', 'Panturrilha sentado', 3, '15', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Ombros',
        exercises: [
          _ex('shoulder_press', 'Desenvolvimento militar', 4, '6-8', rest: 150),
          _ex(
            'dumbbell_shoulder_press',
            'Desenvolvimento com halteres',
            3,
            '8-10',
            rest: 90,
          ),
          _ex('lateral_raise', 'Elevação lateral', 4, '12-15', rest: 45),
          _ex('rear_delt_fly', 'Crucifixo inverso', 3, '12-15', rest: 45),
          _ex('face_pull', 'Face pull', 3, '15', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Braços e abdômen',
        exercises: [
          _ex('bicep_curl', 'Rosca direta', 4, '8-10', rest: 75),
          _ex('hammer_curl', 'Rosca martelo', 3, '10-12', rest: 60),
          _ex('tricep_extension', 'Tríceps testa', 4, '8-10', rest: 75),
          _ex('triceps_pushdown', 'Tríceps na polia', 3, '12-15', rest: 60),
          _ex('leg_raise', 'Elevação de pernas', 3, '12-15', rest: 45),
          _ex('crunch', 'Abdominal supra', 3, '15-20', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'fisiculturismo_feminino',
    title: 'Fisiculturismo feminino',
    summary: 'Ênfase em glúteos e pernas, com superiores para equilibrar.',
    level: 'Avançado',
    daysPerWeek: 5,
    minutes: 65,
    isPremium: true,
    warmUp: [
      '5 min de bicicleta.',
      'Ponte de glúteos: 2 x 15 e cadeira abdutora leve: 1 x 20.',
    ],
    progression:
        'Priorize aumentar a carga da elevação pélvica, do agachamento e do '
        'stiff. Ajuste o volume ao ciclo menstrual e à recuperação: em '
        'semanas de mais cansaço, mantenha a carga e reduza uma série.',
    workouts: [
      TrainingSubWorkout(
        label: 'Glúteos',
        exercises: [
          _ex(
            'hip_thrust',
            'Elevação pélvica',
            4,
            '8-10',
            rest: 120,
            notes: 'Segure 1 s no alto, com o queixo para baixo.',
          ),
          _ex(
            'bulgarian_split_squat',
            'Agachamento búlgaro',
            3,
            '8-10 por lado',
            rest: 90,
          ),
          _ex(
            'cable_kickback',
            'Coice na polia',
            3,
            '12-15 por lado',
            rest: 45,
          ),
          _ex('hip_abduction', 'Cadeira abdutora', 4, '15-20', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Superiores A',
        exercises: [
          _ex('lat_pulldown', 'Puxada frontal', 4, '8-12', rest: 90),
          _ex(
            'dumbbell_shoulder_press',
            'Desenvolvimento com halteres',
            3,
            '8-10',
            rest: 90,
          ),
          _ex(
            'seated_cable_row',
            'Remada baixa na polia',
            3,
            '10-12',
            rest: 75,
          ),
          _ex('lateral_raise', 'Elevação lateral', 4, '12-15', rest: 45),
          _ex('triceps_pushdown', 'Tríceps na polia', 3, '12-15', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Quadríceps',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '6-8', rest: 150, notes: _rir2),
          _ex('hack_squat', 'Agachamento no hack', 3, '10-12', rest: 120),
          _ex('leg_extension', 'Cadeira extensora', 3, '12-15', rest: 60),
          _ex('step_up', 'Subida no degrau', 3, '10 por lado', rest: 75),
          _ex('calf_raise', 'Panturrilha em pé', 4, '12-15', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Superiores B',
        exercises: [
          _ex(
            'dumbbell_row',
            'Remada unilateral com halter',
            3,
            '10 por lado',
            rest: 75,
          ),
          _ex(
            'incline_dumbbell_press',
            'Supino inclinado com halteres',
            3,
            '8-10',
            rest: 90,
          ),
          _ex('face_pull', 'Face pull', 3, '15', rest: 45),
          _ex('rear_delt_fly', 'Crucifixo inverso', 3, '12-15', rest: 45),
          _ex('hammer_curl', 'Rosca martelo', 3, '10-12', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Posterior e glúteos',
        exercises: [
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            4,
            '8-10',
            rest: 120,
          ),
          _ex('leg_curl', 'Mesa flexora', 4, '10-12', rest: 60),
          _ex('hip_thrust', 'Elevação pélvica', 3, '12-15', rest: 90),
          _ex('side_lunge', 'Afundo lateral', 3, '10 por lado', rest: 60),
          _ex('leg_raise', 'Elevação de pernas', 3, '12-15', rest: 45),
        ],
      ),
    ],
  ),

  // ---- Premium: esportes ----
  WorkoutTemplate(
    id: 'atleta',
    title: 'Atleta (desempenho geral)',
    summary:
        'Força, potência e velocidade para quem compete em qualquer esporte.',
    level: 'Avançado',
    daysPerWeek: 3,
    minutes: 60,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: [
      '5 min de trote e deslocamentos.',
      'Mobilidade de quadril 90/90 e de tornozelo.',
      '3 saltos na caixa leves antes da parte principal.',
    ],
    progression:
        'Faça a potência sempre no início, sem cansaço. Fora da temporada, '
        'aumente a carga de força. Durante a temporada, mantenha a potência e '
        'reduza o volume de força pela metade.',
    workouts: [
      TrainingSubWorkout(
        label: 'A: potência e inferiores',
        exercises: [
          _ex(
            'box_jump',
            'Salto na caixa',
            4,
            '3',
            rest: 120,
            notes: _explosive,
          ),
          _ex('squat', 'Agachamento livre', 4, '4-5', rest: 180, notes: _rir2),
          _ex(
            'bulgarian_split_squat',
            'Agachamento búlgaro',
            3,
            '6 por lado',
            rest: 90,
          ),
          _ex('nordic_curl', 'Flexão nórdica assistida', 3, '4-6', rest: 120),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: potência e superiores',
        exercises: [
          _ex(
            'med_ball_slam',
            'Arremesso de bola no chão',
            4,
            '5',
            rest: 90,
            notes: _explosive,
          ),
          _ex('bench_press', 'Supino reto', 4, '4-6', rest: 150),
          _ex('pull_up', 'Barra fixa', 4, '5-8', rest: 120),
          _ex(
            'dumbbell_row',
            'Remada unilateral com halter',
            3,
            '8 por lado',
            rest: 75,
          ),
          _ex('face_pull', 'Face pull', 2, '15', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'C: força posterior e velocidade',
        exercises: [
          _ex(
            'lateral_bound',
            'Salto lateral',
            3,
            '5 por lado',
            rest: 90,
            notes: _explosive,
          ),
          _ex('deadlift', 'Levantamento terra', 4, '3-5', rest: 180),
          _ex('hip_thrust', 'Elevação pélvica', 3, '6-8', rest: 90),
          _ex('farmer_walk', 'Caminhada do fazendeiro', 3, '30 m', rest: 75),
          _ex('calf_raise', 'Panturrilha em pé', 3, '10-12', rest: 45),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'futebol',
    title: 'Futebol',
    summary: 'Arrancada, mudança de direção e proteção do posterior de coxa.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: [
      '5 min de trote leve.',
      'Mobilidade de quadril 90/90 e de tornozelo.',
      '3 arrancadas curtas de 10 m em ritmo crescente.',
    ],
    progression:
        'Fora da temporada: 2 treinos por semana. Durante o campeonato: 1 '
        'treino com metade das séries, nunca na véspera do jogo.',
    workouts: [
      TrainingSubWorkout(
        label: 'Força',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '5', rest: 150, notes: _rir2),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '6-8',
            rest: 120,
          ),
          _ex(
            'nordic_curl',
            'Flexão nórdica assistida',
            3,
            '4-6',
            rest: 120,
            notes: 'Protege o posterior de coxa. Comece com poucas repetições.',
          ),
          _ex('side_lunge', 'Afundo lateral', 3, '8 por lado', rest: 75),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
        ],
      ),
      TrainingSubWorkout(
        label: 'Potência e agilidade',
        exercises: [
          _ex(
            'squat_jump',
            'Agachamento com salto',
            4,
            '4',
            rest: 120,
            notes: _explosive,
          ),
          _ex(
            'lateral_bound',
            'Salto lateral',
            3,
            '5 por lado',
            rest: 90,
            notes: _explosive,
          ),
          _ex('hip_thrust', 'Elevação pélvica', 3, '6-8', rest: 90),
          _ex('calf_raise', 'Panturrilha em pé', 3, '10-12', rest: 45),
          _ex(
            'single_leg_balance',
            'Equilíbrio em um pé',
            2,
            '30 s por lado',
            rest: 30,
          ),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'basquete',
    title: 'Basquete',
    summary: 'Impulsão, aterrissagem segura e tornozelos firmes.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: [
      '5 min de trote e deslocamento lateral.',
      'Mobilidade de tornozelo na parede: 2 x 10 por lado.',
    ],
    progression:
        'Aumente os saltos só se a aterrissagem continuar silenciosa e com os '
        'joelhos alinhados. Durante a temporada, reduza para 1 treino.',
    workouts: [
      TrainingSubWorkout(
        label: 'Força e salto',
        exercises: [
          _ex(
            'squat_jump',
            'Agachamento com salto',
            4,
            '4',
            rest: 120,
            notes: _explosive,
          ),
          _ex('squat', 'Agachamento livre', 4, '5', rest: 150),
          _ex('step_up', 'Subida no degrau', 3, '8 por lado', rest: 75),
          _ex('nordic_curl', 'Flexão nórdica assistida', 2, '4-6', rest: 120),
          _ex('calf_raise', 'Panturrilha em pé', 4, '12', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'Agilidade e core',
        exercises: [
          _ex(
            'lateral_bound',
            'Salto lateral',
            3,
            '5 por lado',
            rest: 90,
            notes: _explosive,
          ),
          _ex(
            'single_leg_balance',
            'Equilíbrio em um pé',
            3,
            '30 s por lado',
            rest: 30,
          ),
          _ex(
            'band_external_rotation',
            'Rotação externa com elástico',
            2,
            '15 por lado',
            rest: 30,
          ),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'corrida',
    title: 'Corrida',
    summary: 'Força para correr com estabilidade e menos sobrecarga.',
    level: 'Iniciante',
    daysPerWeek: 2,
    minutes: 40,
    isPremium: true,
    category: TemplateCategory.sport,
    safetyNote:
        'Faça em dias sem treino forte de corrida. Dor que muda sua '
        'passada é motivo para parar e procurar avaliação.',
    warmUp: [
      '5 min de caminhada rápida.',
      'Mobilidade de tornozelo na parede: 2 x 10 por lado.',
    ],
    progression:
        'Mantenha 2 treinos por semana. Aumente a carga das pernas aos poucos; '
        'nas semanas de prova, faça só 1 treino leve.',
    workouts: [
      TrainingSubWorkout(
        label: 'Força para correr',
        exercises: [
          _ex('step_up', 'Subida no degrau', 3, '8-10 por lado', rest: 75),
          _ex(
            'romanian_deadlift',
            'Stiff (levantamento terra romeno)',
            3,
            '8-10',
            rest: 90,
          ),
          _ex('lunge', 'Afundo', 3, '8 por lado', rest: 75),
          _ex(
            'calf_raise',
            'Panturrilha em pé',
            3,
            '12-15',
            rest: 45,
            notes: 'Desça devagar, em 3 segundos.',
          ),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
          _ex(
            'single_leg_balance',
            'Equilíbrio em um pé',
            2,
            '30 s por lado',
            rest: 30,
          ),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'ciclismo',
    title: 'Ciclismo',
    summary: 'Pernas fortes e lombar protegida para pedalar mais.',
    level: 'Iniciante',
    daysPerWeek: 2,
    minutes: 40,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: ['5 min de pedal leve.', 'Gato e camelo: 1 x 10.'],
    progression:
        'Fora de temporada: aumente a carga do agachamento e da subida no '
        'degrau. Em época de provas, mantenha 1 treino curto.',
    workouts: [
      TrainingSubWorkout(
        label: 'Pernas e core',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '6-8', rest: 120),
          _ex('step_up', 'Subida no degrau', 3, '8 por lado', rest: 75),
          _ex('glute_bridge', 'Ponte de glúteos', 3, '12', rest: 45),
          _ex(
            'hip_90_90',
            'Mobilidade de quadril 90/90',
            2,
            '8 por lado',
            rest: 30,
          ),
          _ex(
            'thoracic_rotation',
            'Rotação de tronco em quatro apoios',
            2,
            '8 por lado',
            rest: 30,
          ),
          _ex('plank', 'Prancha abdominal', 3, '40 s', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'natacao',
    title: 'Natação',
    summary: 'Ombros estáveis, costas fortes e boa rotação de tronco.',
    level: 'Iniciante',
    daysPerWeek: 2,
    minutes: 40,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: [
      'Abertura com elástico: 2 x 15.',
      'Rotação de tronco em quatro apoios: 1 x 8 por lado.',
    ],
    progression:
        'Priorize a qualidade nos exercícios de ombro. Aumente a carga da '
        'puxada e da remada quando chegar ao topo da faixa.',
    workouts: [
      TrainingSubWorkout(
        label: 'Ombros e costas',
        exercises: [
          _ex('lat_pulldown', 'Puxada frontal', 4, '8-12', rest: 90),
          _ex('bent_over_row', 'Remada curvada', 3, '8-10', rest: 90),
          _ex(
            'band_external_rotation',
            'Rotação externa com elástico',
            3,
            '15 por lado',
            rest: 30,
          ),
          _ex('band_pull_apart', 'Abertura com elástico', 3, '15-20', rest: 30),
          _ex('dead_hang', 'Suspensão na barra', 3, '20-30 s', rest: 60),
          _ex('glute_bridge', 'Ponte de glúteos', 3, '12', rest: 45),
          _ex('plank', 'Prancha abdominal', 3, '40 s', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'volei',
    title: 'Vôlei',
    summary: 'Salto, ombros fortes para o ataque e aterrissagem segura.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: [
      '5 min de deslocamentos leves.',
      'Rotação externa com elástico: 2 x 12 por lado.',
    ],
    progression:
        'Aterrisse sempre com os joelhos alinhados aos pés. Durante a '
        'temporada, mantenha 1 treino com metade dos saltos.',
    workouts: [
      TrainingSubWorkout(
        label: 'Salto',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '5', rest: 150),
          _ex(
            'squat_jump',
            'Agachamento com salto',
            4,
            '4',
            rest: 120,
            notes: _explosive,
          ),
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
            rest: 30,
          ),
          _ex('band_pull_apart', 'Abertura com elástico', 3, '15', rest: 30),
          _ex(
            'thoracic_rotation',
            'Rotação de tronco em quatro apoios',
            2,
            '8 por lado',
            rest: 30,
          ),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
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
    warmUp: [
      '5 min de trote leve.',
      'Mobilidade de quadril 90/90 e de tornozelo na parede.',
    ],
    progression:
        'Na areia o tornozelo trabalha mais: aumente primeiro o equilíbrio e '
        'depois os saltos.',
    workouts: [
      TrainingSubWorkout(
        label: 'Pernas e salto',
        exercises: [
          _ex(
            'squat_jump',
            'Agachamento com salto',
            4,
            '4',
            rest: 120,
            notes: _explosive,
          ),
          _ex(
            'lateral_bound',
            'Salto lateral',
            3,
            '5 por lado',
            rest: 90,
            notes: _explosive,
          ),
          _ex('side_lunge', 'Afundo lateral', 3, '8 por lado', rest: 75),
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
          _ex(
            'hip_90_90',
            'Mobilidade de quadril 90/90',
            3,
            '8 por lado',
            rest: 30,
          ),
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
    id: 'beach_tennis',
    title: 'Beach tennis',
    summary: 'Deslocamento lateral, ombro protegido e rotação de tronco.',
    level: 'Iniciante',
    daysPerWeek: 2,
    minutes: 40,
    isPremium: true,
    category: TemplateCategory.sport,
    warmUp: [
      '5 min de deslocamentos laterais leves.',
      'Rotação externa com elástico: 2 x 12 por lado.',
    ],
    progression:
        'Comece pelos exercícios de ombro. Aumente os saltos laterais só '
        'depois de 3 semanas sem dor.',
    workouts: [
      TrainingSubWorkout(
        label: 'Corpo inteiro',
        exercises: [
          _ex('side_lunge', 'Afundo lateral', 3, '8 por lado', rest: 75),
          _ex(
            'lateral_bound',
            'Salto lateral',
            3,
            '5 por lado',
            rest: 90,
            notes: _explosive,
          ),
          _ex(
            'band_external_rotation',
            'Rotação externa com elástico',
            3,
            '15 por lado',
            rest: 30,
          ),
          _ex('band_pull_apart', 'Abertura com elástico', 3, '15', rest: 30),
          _ex(
            'thoracic_rotation',
            'Rotação de tronco em quatro apoios',
            2,
            '8 por lado',
            rest: 30,
          ),
          _ex('calf_raise', 'Panturrilha em pé', 3, '15', rest: 45),
        ],
      ),
    ],
  ),

  // ---- Premium: lutas ----
  WorkoutTemplate(
    id: 'jiu_jitsu',
    title: 'Jiu-jitsu',
    summary: 'Pegada forte, quadril móvel e resistência para o rola.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.fight,
    warmUp: [
      'Fuga de quadril no chão: 2 x 10 por lado.',
      'Gato e camelo: 1 x 10.',
    ],
    progression:
        'Some 5 s por semana na suspensão na barra. Nos dias de treino '
        'técnico intenso, faça só o treino B.',
    workouts: [
      TrainingSubWorkout(
        label: 'A: força e pegada',
        exercises: [
          _ex(
            'deadlift',
            'Levantamento terra',
            4,
            '4-5',
            rest: 180,
            notes: _rir2,
          ),
          _ex('pull_up', 'Barra fixa', 4, '5-8', rest: 120),
          _ex('bent_over_row', 'Remada curvada', 3, '8', rest: 90),
          _ex('dead_hang', 'Suspensão na barra', 3, '30-45 s', rest: 60),
          _ex('farmer_walk', 'Caminhada do fazendeiro', 3, '30 m', rest: 75),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: quadril e core',
        exercises: [
          _ex('kettlebell_swing', 'Balanço com kettlebell', 4, '12', rest: 75),
          _ex(
            'hip_escape',
            'Fuga de quadril no chão',
            3,
            '10 por lado',
            rest: 45,
          ),
          _ex('bear_crawl', 'Caminhada do urso', 3, '20 m', rest: 60),
          _ex(
            'hip_90_90',
            'Mobilidade de quadril 90/90',
            2,
            '8 por lado',
            rest: 30,
          ),
          _ex('side_plank', 'Prancha lateral', 3, '30 s por lado', rest: 30),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'mma',
    title: 'MMA',
    summary: 'Força total e condicionamento em rounds, como na luta.',
    level: 'Avançado',
    daysPerWeek: 2,
    minutes: 55,
    isPremium: true,
    category: TemplateCategory.fight,
    warmUp: ['3 min de pular corda.', 'Sombra leve: 1 round de 2 min.'],
    progression:
        'No treino B, faça 3 rounds de 5 min, como uma luta. Antes de '
        'competir, reduza a força e mantenha o condicionamento.',
    workouts: [
      TrainingSubWorkout(
        label: 'A: força',
        exercises: [
          _ex(
            'deadlift',
            'Levantamento terra',
            4,
            '4',
            rest: 180,
            notes: _rir2,
          ),
          _ex('bench_press', 'Supino reto', 4, '5', rest: 150),
          _ex('pull_up', 'Barra fixa', 4, '5-8', rest: 120),
          _ex('farmer_walk', 'Caminhada do fazendeiro', 3, '30 m', rest: 90),
          _ex('russian_twist', 'Rotação russa', 3, '20', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: condicionamento',
        exercises: [
          _ex(
            'burpee',
            'Burpee',
            3,
            '45 s',
            rest: 15,
            notes: 'Faça os 5 exercícios em sequência: 1 round = 5 min.',
          ),
          _ex(
            'kettlebell_swing',
            'Balanço com kettlebell',
            3,
            '45 s',
            rest: 15,
          ),
          _ex('mountain_climber', 'Escalador', 3, '45 s', rest: 15),
          _ex('shadow_boxing', 'Sombra (shadow boxing)', 3, '45 s', rest: 15),
          _ex(
            'bear_crawl',
            'Caminhada do urso',
            3,
            '45 s',
            rest: 60,
            notes: 'Descanse 1 min entre os rounds.',
          ),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'muay_thai',
    title: 'Muay thai',
    summary: 'Quadril forte para os chutes, equilíbrio e fôlego por round.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.fight,
    warmUp: [
      '3 rounds de 2 min de pular corda.',
      'Mobilidade de quadril 90/90: 1 x 8 por lado.',
    ],
    progression:
        'Aumente a duração dos rounds de 2 para 3 min. Equilíbrio em um pé '
        'de olhos fechados quando estiver fácil.',
    workouts: [
      TrainingSubWorkout(
        label: 'A: pernas e quadril',
        exercises: [
          _ex('squat', 'Agachamento livre', 4, '5-6', rest: 150),
          _ex('step_up', 'Subida no degrau', 3, '8 por lado', rest: 75),
          _ex('kettlebell_swing', 'Balanço com kettlebell', 3, '15', rest: 75),
          _ex(
            'single_leg_balance',
            'Equilíbrio em um pé',
            3,
            '40 s por lado',
            rest: 30,
          ),
          _ex('calf_raise', 'Panturrilha em pé', 3, '15', rest: 45),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: rounds e core',
        exercises: [
          _ex(
            'shadow_boxing',
            'Sombra (shadow boxing)',
            3,
            '3 min',
            rest: 60,
            notes: 'Use joelhadas e chutes, com a guarda alta.',
          ),
          _ex('jump_rope', 'Pular corda', 3, '2 min', rest: 60),
          _ex('russian_twist', 'Rotação russa', 3, '20', rest: 45),
          _ex('side_plank', 'Prancha lateral', 3, '40 s por lado', rest: 30),
          _ex('push_up', 'Flexão de braço', 3, '10-15', rest: 60),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'boxe',
    title: 'Boxe',
    summary: 'Potência de soco, ombros resistentes e fôlego por round.',
    level: 'Intermediário',
    daysPerWeek: 2,
    minutes: 50,
    isPremium: true,
    category: TemplateCategory.fight,
    warmUp: [
      '3 min de pular corda.',
      'Rotação externa com elástico: 2 x 12 por lado.',
    ],
    progression:
        'Aumente os rounds de sombra de 2 para 3 min e diminua o descanso '
        'para 1 min, como numa luta.',
    workouts: [
      TrainingSubWorkout(
        label: 'A: força e potência',
        exercises: [
          _ex('bench_press', 'Supino reto', 4, '5', rest: 150),
          _ex('bent_over_row', 'Remada curvada', 4, '6-8', rest: 120),
          _ex(
            'squat_jump',
            'Agachamento com salto',
            3,
            '4',
            rest: 120,
            notes: _explosive,
          ),
          _ex(
            'russian_twist',
            'Rotação russa',
            3,
            '20',
            rest: 45,
            notes: 'Gire o tronco com força, como num soco.',
          ),
          _ex(
            'band_external_rotation',
            'Rotação externa com elástico',
            2,
            '15 por lado',
            rest: 30,
          ),
        ],
      ),
      TrainingSubWorkout(
        label: 'B: rounds',
        exercises: [
          _ex('shadow_boxing', 'Sombra (shadow boxing)', 4, '3 min', rest: 60),
          _ex('jump_rope', 'Pular corda', 3, '2 min', rest: 60),
          _ex('push_up', 'Flexão de braço', 3, '12-15', rest: 60),
          _ex('mountain_climber', 'Escalador', 3, '40 s', rest: 30),
          _ex('plank', 'Prancha abdominal', 3, '45 s', rest: 30),
        ],
      ),
    ],
  ),

  // ---- Premium: corpo ----
  WorkoutTemplate(
    id: 'postura',
    title: 'Postura no trabalho',
    summary: 'Para quem passa o dia sentado: costas, quadril e ombros.',
    level: 'Iniciante',
    daysPerWeek: 3,
    minutes: 20,
    isPremium: true,
    category: TemplateCategory.care,
    safetyNote:
        'Dor que desce pela perna, formigamento ou dormência precisam de '
        'avaliação antes de treinar.',
    warmUp: ['2 min caminhando e mexendo os ombros.'],
    progression:
        'Faça também nas pausas do trabalho. Depois de 3 semanas, aumente uma '
        'série em cada exercício.',
    workouts: [
      TrainingSubWorkout(
        label: 'Rotina',
        exercises: [
          _ex('cat_cow', 'Gato e camelo', 2, '10', rest: 20),
          _ex(
            'thoracic_rotation',
            'Rotação de tronco em quatro apoios',
            2,
            '8 por lado',
            rest: 20,
          ),
          _ex('band_pull_apart', 'Abertura com elástico', 3, '15', rest: 30),
          _ex('glute_bridge', 'Ponte de glúteos', 3, '12', rest: 30),
          _ex(
            'hip_90_90',
            'Mobilidade de quadril 90/90',
            2,
            '8 por lado',
            rest: 20,
          ),
          _ex('plank', 'Prancha abdominal', 2, '30 s', rest: 30),
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
    warmUp: ['3 min de caminhada leve.'],
    progression:
        'Cada semana, tente ir um pouco mais longe no movimento, sempre sem '
        'dor. Respire devagar durante os exercícios.',
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
          _ex(
            'dead_hang',
            'Suspensão na barra',
            2,
            '10-20 s',
            rest: 60,
            notes: 'Opcional: com os pés no chão, se precisar.',
          ),
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
    warmUp: ['3 min de marcha no lugar, segurando em um apoio.'],
    progression:
        'Quando fizer todas as séries com facilidade, some 2 repetições. No '
        'equilíbrio, solte uma das mãos do apoio aos poucos.',
    workouts: [
      TrainingSubWorkout(
        label: 'Força e equilíbrio',
        exercises: [
          _ex(
            'sit_to_stand',
            'Sentar e levantar da cadeira',
            2,
            '8-10',
            rest: 90,
          ),
          _ex('wall_push_up', 'Flexão na parede', 2, '8-10', rest: 90),
          _ex(
            'step_up',
            'Subida no degrau',
            2,
            '6 por lado',
            rest: 90,
            notes: 'Degrau baixo, com corrimão ou apoio ao lado.',
          ),
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
          _ex('glute_bridge', 'Ponte de glúteos', 2, '8-10', rest: 60),
        ],
      ),
    ],
  ),
];
