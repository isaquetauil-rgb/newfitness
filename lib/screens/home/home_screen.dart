import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../ai/ai_hub_screen.dart';
import '../exercises/exercise_library_screen.dart';
import '../instructor/instructor_dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import '../reminders/reminders_screen.dart';
import '../workout/workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isInstructor = context.watch<AuthProvider>().profile?.role == UserRole.instructor;

    final screens = <Widget>[
      const WorkoutScreen(),
      const ExerciseLibraryScreen(),
      const ProgressScreen(),
      const RemindersScreen(),
      const AiHubScreen(),
      if (isInstructor) const InstructorDashboardScreen(),
      const ProfileScreen(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center_outlined),
        activeIcon: Icon(Icons.fitness_center),
        label: 'Treino',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.video_library_outlined),
        activeIcon: Icon(Icons.video_library),
        label: 'Exercícios',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.show_chart_outlined),
        activeIcon: Icon(Icons.show_chart),
        label: 'Progresso',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.notifications_outlined),
        activeIcon: Icon(Icons.notifications),
        label: 'Lembretes',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.smart_toy_outlined),
        activeIcon: Icon(Icons.smart_toy),
        label: 'IA',
      ),
      if (isInstructor)
        const BottomNavigationBarItem(
          icon: Icon(Icons.groups_outlined),
          activeIcon: Icon(Icons.groups),
          label: 'Alunos',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];

    // Evita índice inválido se o papel mudar (ex: perfil ainda carregando).
    final safeIndex = _index >= screens.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: items,
      ),
    );
  }
}
