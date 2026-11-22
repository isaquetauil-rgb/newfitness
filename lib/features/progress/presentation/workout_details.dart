import 'package:flutter/material.dart';

import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/format.dart';

/// Uma série em texto: "8 × 62,5 kg · RPE 8", "40 m · 1 min · 24 kg",
/// "Aquecimento: 12 × 20 kg".
String describeSet(WorkoutSet s) {
  final parts = <String>[];
  if (s.reps > 0 && s.weightKg > 0) {
    parts.add('${s.reps} × ${formatKg(s.weightKg)}');
  } else if (s.reps > 0) {
    parts.add('${s.reps} reps');
  } else if (s.weightKg > 0) {
    parts.add(formatKg(s.weightKg));
  }
  if (s.distanceMeters > 0) parts.add(formatDistance(s.distanceMeters));
  if (s.seconds > 0) parts.add(formatSeconds(s.seconds));
  if (s.rpe != null) parts.add(formatRpe(s.rpe!));
  final text = parts.isEmpty ? '—' : parts.join(' · ');
  return s.type == SetType.normal ? text : '${s.type.label}: $text';
}

/// Detalhes de um treino do histórico: exercícios, séries (com distância,
/// tempo, RPE) e anotações.
class WorkoutDetails extends StatelessWidget {
  const WorkoutDetails({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in workout.exercises) ...[
            const SizedBox(height: 8),
            Text(
              e.exerciseName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            for (var i = 0; i < e.sets.length; i++) ...[
              Text('${i + 1}. ${describeSet(e.sets[i])}'),
              if ((e.sets[i].notes ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('“${e.sets[i].notes!.trim()}”', style: muted),
                ),
            ],
          ],
          if ((workout.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Anotação do treino', style: muted),
            Text(workout.notes!.trim()),
          ],
        ],
      ),
    );
  }
}
