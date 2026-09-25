/// Nomes/caminhos de coleções do Firestore num único lugar, para não
/// espalhar strings soltas por `FirestoreService` (e evitar erro de
/// digitação num caminho usado em vários métodos). O SDK do Firestore aceita
/// caminhos com múltiplos segmentos em `collection(...)`, então os helpers
/// abaixo montam o caminho completo de cada subcoleção de `users/{uid}`.
class FirestorePaths {
  FirestorePaths._();

  static const users = 'users';

  /// Pedidos para virar personal/nutricionista — um por usuário (id = uid).
  static const professionalRequests = 'professional_requests';
  static const exercises = 'exercises';
  static const muscleGroups = 'muscle_groups';
  static const equipment = 'equipment';

  static String workouts(String uid) => '$users/$uid/workouts';
  static String reminders(String uid) => '$users/$uid/reminders';
  static String bodyPhotos(String uid) => '$users/$uid/body_photos';
  static String physicalAssessments(String uid) =>
      '$users/$uid/physical_assessments';
  static String chatMessages(String uid) => '$users/$uid/chat_messages';
  static String mealPhotos(String uid) => '$users/$uid/meal_photos';
  static String students(String instructorId) =>
      '$users/$instructorId/students';
  static String nutritionStudents(String nutritionistId) =>
      '$users/$nutritionistId/nutrition_students';
  static String nutritionChat(String uid) => '$users/$uid/nutrition_chat';
  static String nutritionPlans(String uid) => '$users/$uid/nutrition_plans';
  static String trainingPlans(String uid) => '$users/$uid/training_plans';
  static String planTemplates(String instructorId) =>
      '$users/$instructorId/plan_templates';
  static String appointments(String uid) => '$users/$uid/appointments';
  static String customExercises(String instructorUid) =>
      '$users/$instructorUid/custom_exercises';

  /// Rollup de evolução por exercício (ver `ExerciseProgressRecord`) — um
  /// documento por exercício já treinado por aquele usuário.
  static String progressRecords(String uid) => '$users/$uid/progress_records';

  /// Nome da collection group (mesmo nome final de qualquer
  /// `appointments(uid)`) — usado por `collectionGroup('appointments')`.
  static const appointmentsGroup = 'appointments';

  /// Doc único com o estado da assinatura — só a Cloud Function grava.
  static String financeSubscriptionDoc(String uid) =>
      '$users/$uid/finance/subscription';
  static String financePayments(String uid) =>
      '${financeSubscriptionDoc(uid)}/payments';

  /// Contagem de uso de IA do mês corrente — `month` no formato `yyyy-MM`,
  /// mesmo formato usado pelo backend (`functions/src/index.ts`).
  static String aiUsageDoc(String uid, String month) =>
      '$users/$uid/ai_usage/$month';
}
