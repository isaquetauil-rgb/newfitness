import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/features/auth/data/auth_service.dart';
import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/shared/services/storage_service.dart';

final getIt = GetIt.instance;

/// Registra os services compartilhados (wrappers finos sobre Firebase e
/// notificações locais) como singletons preguiçosos. Cada `ChangeNotifier`
/// em `features/*/logic` recebe esses services pelo construtor — o injetor
/// só resolve QUEM cria cada instância; o estado da UI continua sendo
/// gerenciado por `provider`.
///
/// Chame [setupInjector] uma vez em `main()`, antes de `runApp`, e aguarde
/// [GetIt.allReady] para garantir que dependências assíncronas (como
/// [LocalPrefs]) estejam prontas.
void setupInjector() {
  getIt
    ..registerLazySingleton<AuthService>(AuthService.new)
    ..registerLazySingleton<FirestoreService>(FirestoreService.new)
    ..registerLazySingleton<StorageService>(StorageService.new)
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<AiService>(AiService.new)
    ..registerSingletonAsync<LocalPrefs>(
      () async => LocalPrefs(await SharedPreferences.getInstance()),
    );
}
