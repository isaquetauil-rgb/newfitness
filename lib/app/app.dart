import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_router.dart';
import 'package:newfitness/app/theme/app_theme.dart';
import 'package:newfitness/app/theme/theme_provider.dart';
import 'package:newfitness/features/ai/logic/chat_provider.dart';
import 'package:newfitness/features/ai/logic/meal_photo_provider.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/agenda/logic/appointment_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/features/finance/logic/finance_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';
import 'package:newfitness/features/instructor/logic/plan_template_provider.dart';
import 'package:newfitness/features/notifications/logic/reminder_provider.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_chat_provider.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_plan_provider.dart';
import 'package:newfitness/features/professional/logic/professional_request_provider.dart';
import 'package:newfitness/features/progress/logic/body_photo_provider.dart';
import 'package:newfitness/features/progress/logic/physical_assessment_provider.dart';
import 'package:newfitness/features/progress/logic/progress_record_provider.dart';
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

  // Criados aqui (e não só dentro do MultiProvider) para poder reagir à
  // troca de usuário — ver [_onAuthChanged].
  final _workoutProvider = WorkoutProvider();
  final _exerciseProvider = ExerciseProvider();
  final _taxonomyProvider = ExerciseTaxonomyProvider();
  final _reminderProvider = ReminderProvider();
  String? _sessionUid;

  @override
  void initState() {
    super.initState();
    _authProvider.addListener(_onAuthChanged);
  }

  /// Ao sair ou trocar de conta: descarta o treino em andamento (senão o
  /// próximo usuário veria — e tentaria salvar — o treino do anterior) e
  /// refaz as assinaturas da biblioteca, que morrem com permission-denied
  /// no logout e deixariam a lista congelada no próximo login.
  void _onAuthChanged() {
    final uid = _authProvider.user?.uid;
    if (uid == _sessionUid) return;
    final hadSession = _sessionUid != null;
    _sessionUid = uid;
    // cancelWorkout também apaga o rascunho local — no logout nada do
    // treino fica salvo no aparelho.
    if (hadSession) {
      _workoutProvider.cancelWorkout();
      // Lembretes são por conta: ao sair, param de tocar neste aparelho.
      _reminderProvider.clear();
    }
    if (uid != null) {
      // App reaberto no meio de um treino: restaura o rascunho, se for
      // deste usuário (o store descarta o de qualquer outro).
      _workoutProvider.restoreFor(uid);
      _exerciseProvider.restart();
      _taxonomyProvider.restart();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _authProvider.dispose();
    _workoutProvider.dispose();
    _exerciseProvider.dispose();
    _taxonomyProvider.dispose();
    _reminderProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<WorkoutProvider>.value(value: _workoutProvider),
        ChangeNotifierProvider<ExerciseProvider>.value(
          value: _exerciseProvider,
        ),
        ChangeNotifierProvider<ExerciseTaxonomyProvider>.value(
          value: _taxonomyProvider,
        ),
        ChangeNotifierProvider(create: (_) => ProgressRecordProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider<ReminderProvider>.value(
          value: _reminderProvider,
        ),
        ChangeNotifierProvider(create: (_) => BodyPhotoProvider()),
        ChangeNotifierProvider(create: (_) => PhysicalAssessmentProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MealPhotoProvider()),
        ChangeNotifierProvider(create: (_) => TrainingPlanProvider()),
        ChangeNotifierProvider(create: (_) => InstructorAiProvider()),
        ChangeNotifierProvider(create: (_) => PlanTemplateProvider()),
        ChangeNotifierProvider(create: (_) => CustomExerciseProvider()),
        ChangeNotifierProvider(create: (_) => NutritionChatProvider()),
        ChangeNotifierProvider(create: (_) => NutritionPlanProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => TimelineProvider()),
        ChangeNotifierProvider(create: (_) => ProfessionalRequestProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp.router(
          title: 'NewFitness',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
