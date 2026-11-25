import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'core/error/error_handler.dart';
import 'core/firebase/local_emulators.dart';
import 'core/logging/app_logger.dart';
import 'features/body_map/data/muscle_map_license.dart';
import 'firebase_options.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      AppLogger.init();
      ErrorHandler.init();
      registerMuscleMapLicense();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (useLocalFirebase) await connectToLocalFirebase();
      await initializeDateFormatting('pt_BR');

      setupInjector();
      await getIt.allReady();

      // A barra de navegação do Android fica escondida pelo lado nativo
      // (MainActivity.kt), que funciona em todos os celulares.

      runApp(const NewFitnessApp());
    },
    (error, stack) {
      AppLogger.of('main')
          .severe('Erro não tratado fora do ciclo do Flutter', error, stack);
    },
  );
}
