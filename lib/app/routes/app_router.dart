import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:newfitness/app/widgets/app_shell.dart';
import 'package:newfitness/app/widgets/coming_soon_screen.dart';
import 'package:newfitness/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:newfitness/features/admin/presentation/admin_exercise_form_screen.dart';
import 'package:newfitness/features/admin/presentation/admin_exercises_screen.dart';
import 'package:newfitness/features/admin/presentation/admin_taxonomy_screen.dart';
import 'package:newfitness/features/admin/presentation/admin_users_screen.dart';
import 'package:newfitness/features/agenda/presentation/agenda_screen.dart';
import 'package:newfitness/features/ai/presentation/ai_hub_screen.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/forgot_password_screen.dart';
import 'package:newfitness/features/auth/presentation/login_screen.dart';
import 'package:newfitness/features/auth/presentation/register_screen.dart';
import 'package:newfitness/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:newfitness/features/exercises/presentation/exercise_library_screen.dart';
import 'package:newfitness/features/finance/presentation/finance_screen.dart';
import 'package:newfitness/features/home/presentation/home_dashboard_screen.dart';
import 'package:newfitness/features/instructor/presentation/custom_exercise_form_screen.dart';
import 'package:newfitness/features/instructor/presentation/custom_exercises_screen.dart';
import 'package:newfitness/features/instructor/presentation/instructor_dashboard_screen.dart';
import 'package:newfitness/features/instructor/presentation/plan_editor_screen.dart';
import 'package:newfitness/features/instructor/presentation/plan_templates_screen.dart';
import 'package:newfitness/features/instructor/presentation/student_detail_screen.dart';
import 'package:newfitness/features/notifications/presentation/reminders_screen.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_plan_editor_screen.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_screen.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_student_detail_screen.dart';
import 'package:newfitness/features/nutrition/presentation/nutritionist_dashboard_screen.dart';
import 'package:newfitness/features/profile/presentation/profile_screen.dart';
import 'package:newfitness/features/progress/presentation/body_progress_screen.dart';
import 'package:newfitness/features/progress/presentation/physical_assessment_screen.dart';
import 'package:newfitness/features/progress/presentation/progress_calendar_screen.dart';
import 'package:newfitness/features/progress/presentation/progress_screen.dart';
import 'package:newfitness/features/timeline/presentation/timeline_screen.dart';
import 'package:newfitness/features/workout/presentation/exercise_picker_screen.dart';
import 'package:newfitness/features/workout/presentation/workout_screen.dart';
import 'package:newfitness/shared/models/body_photo.dart';
import 'package:newfitness/shared/models/exercise.dart';

import 'app_routes.dart';

/// Monta o [GoRouter] do app. Recebe o [AuthProvider] já criado (vindo do
/// `MultiProvider` em `app/app.dart`) para:
///  - `redirect`: manda usuário deslogado para `/login` e usuário logado
///    para longe das telas de autenticação — sem precisar de um widget
///    "AuthGate" fazendo esse trabalho em `build()`.
///  - `refreshListenable`: como [AuthProvider] já é um `ChangeNotifier`,
///    o router reavalia o `redirect` sozinho sempre que o login muda.
GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggedIn = authProvider.isLoggedIn;
      final loggingIn =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;

      if (!loggedIn && !loggingIn) return AppRoutes.login;
      if (loggedIn && loggingIn) return AppRoutes.home;

      // Painel admin: mesmo escondido da barra de navegação para quem não
      // é dono do app, um link direto não pode dar acesso.
      final isAdminRoute = state.matchedLocation.startsWith(AppRoutes.admin);
      if (isAdminRoute && !authProvider.isAdmin) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const ForgotPasswordScreen()),
      ),

      // Itens do menu lateral sem aba própria — telas cheias com seta de
      // voltar, fora do StatefulShellRoute (mesmo padrão de detalhe usado
      // em exercícios/progresso).
      GoRoute(
        path: AppRoutes.progressCalendar,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const ProgressCalendarScreen()),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const TimelineScreen()),
      ),
      GoRoute(
        path: AppRoutes.physicalAssessment,
        pageBuilder: (context, state) {
          final args = state.extra as PhysicalAssessmentArgs?;
          return _fadeThrough(
            state,
            PhysicalAssessmentScreen(
              studentUid: args?.studentUid,
              studentName: args?.studentName,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.finance,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const FinanceScreen()),
      ),
      GoRoute(
        path: AppRoutes.agenda,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const AgendaScreen()),
      ),
      GoRoute(
        path: AppRoutes.nutrition,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const NutritionScreen()),
      ),
      GoRoute(
        path: AppRoutes.myCards,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          const ComingSoonScreen(
            title: 'Meus cartões',
            icon: Icons.credit_card_outlined,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.activeContracts,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          const ComingSoonScreen(
            title: 'Contratos ativos',
            icon: Icons.description_outlined,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.documents,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          const ComingSoonScreen(
            title: 'Documentos',
            icon: Icons.folder_outlined,
          ),
        ),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const HomeDashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.workout,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const WorkoutScreen()),
                routes: [
                  GoRoute(
                    path: 'exercise-picker',
                    pageBuilder: (context, state) =>
                        _fadeThrough(state, const ExercisePickerScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.exercises,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const ExerciseLibraryScreen()),
                routes: [
                  GoRoute(
                    path: 'detail',
                    redirect: (context, state) =>
                        state.extra is Exercise ? null : AppRoutes.exercises,
                    pageBuilder: (context, state) => _fadeThrough(
                      state,
                      ExerciseDetailScreen(exercise: state.extra! as Exercise),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const ProgressScreen()),
                routes: [
                  GoRoute(
                    path: 'photo',
                    redirect: (context, state) =>
                        state.extra is BodyPhoto ? null : AppRoutes.progress,
                    pageBuilder: (context, state) => _fadeThrough(
                      state,
                      PhotoViewerScreen(photo: state.extra! as BodyPhoto),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const RemindersScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ai,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const AiHubScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.instructor,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const InstructorDashboardScreen()),
                routes: [
                  GoRoute(
                    path: 'templates',
                    pageBuilder: (context, state) =>
                        _fadeThrough(state, const PlanTemplatesScreen()),
                  ),
                  GoRoute(
                    path: 'exercises',
                    pageBuilder: (context, state) =>
                        _fadeThrough(state, const CustomExercisesScreen()),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) => _fadeThrough(
                          state,
                          CustomExerciseFormScreen(
                            existing: state.extra as Exercise?,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'student',
                    // Sem `extra` (ex: recarregar a página no navegador ou
                    // link direto) a tela não tem o aluno: volta para a
                    // lista em vez de quebrar com tela vermelha.
                    redirect: (context, state) =>
                        state.extra is StudentDetailArgs
                        ? null
                        : AppRoutes.instructor,
                    pageBuilder: (context, state) {
                      final args = state.extra! as StudentDetailArgs;
                      return _fadeThrough(
                        state,
                        StudentDetailScreen(
                          studentUid: args.uid,
                          studentName: args.name,
                          initialNotes: args.notes,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'plan',
                        redirect: (context, state) =>
                            state.extra is PlanEditorArgs
                            ? null
                            : AppRoutes.instructor,
                        pageBuilder: (context, state) => _fadeThrough(
                          state,
                          PlanEditorScreen(
                            args: state.extra! as PlanEditorArgs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.admin,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const AdminDashboardScreen()),
                routes: [
                  GoRoute(
                    path: 'users',
                    pageBuilder: (context, state) =>
                        _fadeThrough(state, const AdminUsersScreen()),
                  ),
                  GoRoute(
                    path: 'exercises',
                    pageBuilder: (context, state) =>
                        _fadeThrough(state, const AdminExercisesScreen()),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) => _fadeThrough(
                          state,
                          AdminExerciseFormScreen(
                            existing: state.extra as Exercise?,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'taxonomy',
                    pageBuilder: (context, state) =>
                        _fadeThrough(state, const AdminTaxonomyScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const ProfileScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.nutritionist,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const NutritionistDashboardScreen()),
                routes: [
                  GoRoute(
                    path: 'student',
                    redirect: (context, state) =>
                        state.extra is NutritionStudentDetailArgs
                        ? null
                        : AppRoutes.nutritionist,
                    pageBuilder: (context, state) {
                      final args = state.extra! as NutritionStudentDetailArgs;
                      return _fadeThrough(
                        state,
                        NutritionStudentDetailScreen(args: args),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'plan',
                        redirect: (context, state) =>
                            state.extra is NutritionPlanEditorArgs
                            ? null
                            : AppRoutes.nutritionist,
                        pageBuilder: (context, state) => _fadeThrough(
                          state,
                          NutritionPlanEditorScreen(
                            args: state.extra! as NutritionPlanEditorArgs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Transição Material "fade through" (pacote oficial `animations`) central
/// — aplicada a toda navegação de rota de uma vez, em vez de repetir
/// `PageTransitionsBuilder` em cada `MaterialPageRoute` manualmente.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      );
    },
  );
}

/// Argumentos para `/instructor/student` (evita passar UID/nome soltos por
/// `extra` sem tipo).
class StudentDetailArgs {
  const StudentDetailArgs({required this.uid, required this.name, this.notes});
  final String uid;
  final String name;
  final String? notes;
}

/// Argumentos opcionais para `/physical-assessment` — quando o instrutor abre
/// a avaliação física de um aluno específico (sem eles, a tela mostra a
/// avaliação do próprio usuário logado).
class PhysicalAssessmentArgs {
  const PhysicalAssessmentArgs({
    required this.studentUid,
    required this.studentName,
  });
  final String studentUid;
  final String studentName;
}
