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
  static const instructorStudent = '/instructor/student';
  static const instructorPlanEditor = '/instructor/student/plan';
  static const profile = '/profile';
}
