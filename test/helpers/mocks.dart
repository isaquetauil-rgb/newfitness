import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/features/auth/data/auth_service.dart';
import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/shared/models/reminder.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/shared/services/storage_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockStorageService extends Mock implements StorageService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAiService extends Mock implements AiService {}

class MockUser extends Mock implements User {}

/// Mocktail exige um valor de exemplo (`registerFallbackValue`) para
/// qualquer tipo não-primitivo usado com matchers como `any()`. Chame uma
/// vez por arquivo de teste, em `setUpAll`.
void registerTestFallbackValues() {
  registerFallbackValue(
    const Reminder(
      id: '',
      type: ReminderType.water,
      label: '',
      hour: 0,
      minute: 0,
    ),
  );
  registerFallbackValue(
    Workout(id: '', userId: '', date: DateTime(2024), exercises: const []),
  );
  registerFallbackValue(const UserProfile(uid: '', name: '', email: ''));
}
