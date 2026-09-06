import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'core/error/error_handler.dart';
import 'core/logging/app_logger.dart';
import 'firebase_options.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      AppLogger.init();
      ErrorHandler.init();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await initializeDateFormatting('pt_BR');

      setupInjector();
      await getIt.allReady();

      runApp(const NewFitnessApp());
    },
    (error, stack) {
      AppLogger.of('main')
          .severe('Erro não tratado fora do ciclo do Flutter', error, stack);
    },
  );
}
