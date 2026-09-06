import '../models/exercise.dart';

/// Exercícios de exemplo para popular a biblioteca inicialmente.
///
/// As URLs de vídeo abaixo são placeholders (Google Test Videos, de uso
/// livre) — troque pelos vídeos reais do seu catálogo (Firebase Storage,
/// YouTube, etc.) antes de publicar o app.
final List<Exercise> sampleExercises = [
  Exercise(
    id: 'squat',
    name: 'Agachamento livre',
    muscleGroup: 'Pernas',
    equipment: 'Barra',
    description: 'Exercício composto fundamental para quadríceps, glúteos e posterior de coxa.',
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    instructions: const [
      'Posicione a barra sobre o trapézio, pés na largura dos ombros.',
      'Desça flexionando quadril e joelhos, mantendo o peito erguido.',
      'Desça até as coxas ficarem paralelas ao chão.',
      'Suba empurrando o chão com os pés, estendendo quadril e joelhos.',
    ],
  ),
  Exercise(
    id: 'bench_press',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: 'Principal exercício para desenvolvimento do peitoral.',
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    instructions: const [
      'Deite no banco com os pés apoiados no chão.',
      'Segure a barra um pouco mais aberta que a largura dos ombros.',
      'Desça a barra até tocar levemente o peito.',
      'Empurre a barra de volta até estender os cotovelos.',
    ],
  ),
  Exercise(
    id: 'deadlift',
    name: 'Levantamento terra',
    muscleGroup: 'Costas',
    equipment: 'Barra',
    description: 'Exercício composto para posterior de coxa, glúteos e lombar.',
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    instructions: const [
      'Fique com os pés na largura do quadril, barra próxima às canelas.',
      'Segure a barra e mantenha a coluna neutra.',
      'Puxe o peso estendendo quadril e joelhos ao mesmo tempo.',
      'Finalize em pé, ombros para trás, e retorne controladamente.',
    ],
  ),
  Exercise(
    id: 'pull_up',
    name: 'Barra fixa',
    muscleGroup: 'Costas',
    equipment: 'Peso do corpo',
    description: 'Excelente para dorsais e bíceps.',
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    instructions: const [
      'Segure a barra com pegada pronada, um pouco mais aberta que os ombros.',
      'Puxe o corpo até o queixo passar da barra.',
      'Desça de forma controlada até os braços ficarem estendidos.',
    ],
  ),
  Exercise(
    id: 'shoulder_press',
    name: 'Desenvolvimento com halteres',
    muscleGroup: 'Ombro',
    equipment: 'Halteres',
    description: 'Desenvolve deltoides e estabilizadores do ombro.',
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    instructions: const [
      'Sente-se com um halter em cada mão na altura dos ombros.',
      'Empurre os halteres para cima até estender os braços.',
      'Desça controladamente até a posição inicial.',
    ],
  ),
  Exercise(
    id: 'plank',
    name: 'Prancha abdominal',
    muscleGroup: 'Core',
    equipment: 'Peso do corpo',
    description: 'Fortalece o core e melhora a estabilidade da coluna.',
    videoUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    instructions: const [
      'Apoie antebraços e pontas dos pés no chão.',
      'Mantenha o corpo alinhado, sem elevar ou baixar o quadril.',
      'Contraia o abdômen e segure a posição pelo tempo determinado.',
    ],
  ),
];
