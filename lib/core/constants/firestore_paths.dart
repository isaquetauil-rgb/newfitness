/// Nomes/caminhos de coleções do Firestore num único lugar, para não
/// espalhar strings soltas por `FirestoreService` (e evitar erro de
/// digitação num caminho usado em vários métodos). O SDK do Firestore aceita
/// caminhos com múltiplos segmentos em `collection(...)`, então os helpers
/// abaixo montam o caminho completo de cada subcoleção de `users/{uid}`.
class FirestorePaths {
  FirestorePaths._();

  static const users = 'users';
  static const exercises = 'exercises';

  static String workouts(String uid) => '$users/$uid/workouts';
  static String reminders(String uid) => '$users/$uid/reminders';
  static String bodyPhotos(String uid) => '$users/$uid/body_photos';
  static String chatMessages(String uid) => '$users/$uid/chat_messages';
  static String mealPhotos(String uid) => '$users/$uid/meal_photos';
  static String students(String instructorId) =>
      '$users/$instructorId/students';
}
