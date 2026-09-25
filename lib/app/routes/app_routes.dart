/// Caminhos de rota nomeados num único lugar — nada de strings soltas
/// espalhadas pelas telas. Fica separado de `app_router.dart` (que monta o
/// `GoRouter` e por isso importa todas as telas) para que qualquer widget
/// possa navegar (`context.go(AppRoutes.workout)`) sem criar uma
/// dependência circular com o router.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const home = '/home';
  static const workout = '/workout';
  static const workoutExercisePicker = '/workout/exercise-picker';
  static const exercises = '/exercises';
  static const exerciseDetail = '/exercises/detail';
  static const progress = '/progress';
  static const progressPhoto = '/progress/photo';
  static const notifications = '/notifications';
  static const ai = '/ai';
  static const instructor = '/instructor';
  static const instructorTemplates = '/instructor/templates';
  static const instructorExercises = '/instructor/exercises';
  static const instructorExerciseForm = '/instructor/exercises/edit';
  static const nutritionist = '/nutritionist';
  static const nutritionistStudent = '/nutritionist/student';
  static const nutritionistPlanEditor = '/nutritionist/student/plan';
  static const instructorStudent = '/instructor/student';
  static const instructorPlanEditor = '/instructor/student/plan';
  static const admin = '/admin';
  static const adminUsers = '/admin/users';
  static const adminExercises = '/admin/exercises';
  static const adminExerciseForm = '/admin/exercises/edit';
  static const adminTaxonomy = '/admin/taxonomy';
  static const profile = '/profile';
  static const progressCalendar = '/progress-calendar';

  // Itens do menu lateral inspirados no Next Fit — telas "em breve" até
  // termos backend real de agenda/pagamento/contrato.
  static const timeline = '/timeline';
  static const physicalAssessment = '/physical-assessment';
  static const finance = '/finance';
  static const agenda = '/agenda';
  static const nutrition = '/nutrition';
  static const myCards = '/my-cards';
  static const activeContracts = '/active-contracts';
  static const documents = '/documents';
}
