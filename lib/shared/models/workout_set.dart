/// Uma série individual de um exercício (ex: 10 repetições com 40kg).
class WorkoutSet {
  int reps;
  double weightKg;
  bool completed;

  WorkoutSet({this.reps = 0, this.weightKg = 0, this.completed = false});

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      reps: (map['reps'] as num?)?.toInt() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'reps': reps, 'weightKg': weightKg, 'completed': completed};
  }

  WorkoutSet copy() =>
      WorkoutSet(reps: reps, weightKg: weightKg, completed: completed);
}
