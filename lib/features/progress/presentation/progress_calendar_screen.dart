import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/workout.dart';

/// "Meu Progresso" — calendário mensal com os dias em que o usuário
/// registrou pelo menos um treino destacados. Calculado em cima de
/// `WorkoutProvider.watchHistory` (sem coleção nova no Firestore).
class ProgressCalendarScreen extends StatefulWidget {
  const ProgressCalendarScreen({super.key});

  @override
  State<ProgressCalendarScreen> createState() => _ProgressCalendarScreenState();
}

class _ProgressCalendarScreenState extends State<ProgressCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final workoutProvider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Progresso')),
      body: uid == null
          ? const Center(child: Text('Faça login para ver seu progresso'))
          : StreamBuilder<List<Workout>>(
              stream: workoutProvider.watchHistory(uid),
              builder: (context, snapshot) {
                final workouts = snapshot.data ?? [];
                final workoutDays = workouts
                    .map((w) => _dateOnly(w.date))
                    .toSet();
                final today = _dateOnly(DateTime.now());

                final daysInMonth = DateUtils.getDaysInMonth(
                  _month.year,
                  _month.month,
                );
                final firstDay = DateTime(_month.year, _month.month, 1);
                // weekday: 1=segunda..7=domingo; queremos offset a partir de domingo.
                final leadingBlanks = firstDay.weekday % 7;

                final daysThisMonth = List.generate(
                  daysInMonth,
                  (i) => DateTime(_month.year, _month.month, i + 1),
                );
                final presentCount = daysThisMonth
                    .where((d) => workoutDays.contains(d))
                    .length;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: () => _changeMonth(-1),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMMM \'de\' y',
                                      'pt_BR',
                                    ).format(_month),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () => _changeMonth(1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final label in _weekdayLabels)
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                    ),
                                itemCount: leadingBlanks + daysInMonth,
                                itemBuilder: (context, index) {
                                  if (index < leadingBlanks) {
                                    return const SizedBox.shrink();
                                  }
                                  final day =
                                      daysThisMonth[index - leadingBlanks];
                                  final isToday = day == today;
                                  final hasWorkout = workoutDays.contains(day);

                                  return Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isToday
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : hasWorkout
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.15)
                                            : null,
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          color: isToday
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: hasWorkout || isToday
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.event_available_outlined),
                          title: const Text('Você marcou presença'),
                          trailing: Text(
                            '$presentCount dias esse mês',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(content: Text('Em breve')),
                            ),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Compartilhar'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.go(AppRoutes.progress),
                        icon: const Icon(Icons.show_chart),
                        label: const Text('Progresso completo'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
