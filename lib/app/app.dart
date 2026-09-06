import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_router.dart';
import 'package:newfitness/app/theme/app_theme.dart';
import 'package:newfitness/features/ai/logic/chat_provider.dart';
import 'package:newfitness/features/ai/logic/meal_photo_provider.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';
import 'package:newfitness/features/notifications/logic/reminder_provider.dart';
import 'package:newfitness/features/progress/logic/body_photo_provider.dart';
import 'package:newfitness/features/timeline/logic/timeline_provider.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';

/// Widget raiz do app. O [AuthProvider] e o [GoRouter] são criados uma única
/// vez aqui (não a cada rebuild) porque o router usa
/// `refreshListenable: authProvider` para reagir a mudanças de login sozinho
/// — recriar o [GoRouter] a cada build resetaria a pilha de navegação.
class NewFitnessApp extends StatefulWidget {
  const NewFitnessApp({super.key});

  @override
  State<NewFitnessApp> createState() => _NewFitnessAppState();
}

class _NewFitnessAppState extends State<NewFitnessApp> {
  late final AuthProvider _authProvider = AuthProvider();
  late final GoRouter _router = buildAppRouter(_authProvider);

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => BodyPhotoProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MealPhotoProvider()),
        ChangeNotifierProvider(create: (_) => TrainingPlanProvider()),
        ChangeNotifierProvider(create: (_) => InstructorAiProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => TimelineProvider()),
      ],
      child: MaterialApp.router(
        title: 'NewFitness',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
