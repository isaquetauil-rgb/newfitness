enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeLabel on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Café da manhã';
      case MealType.lunch:
        return 'Almoço';
      case MealType.dinner:
        return 'Janta';
      case MealType.snack:
        return 'Lanche';
    }
  }
}

class MealPhoto {
  final String id;
  final String userId;
  final DateTime date;
  final MealType mealType;
  final String imageUrl;
  final String? aiAnalysis;

  const MealPhoto({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealType,
    required this.imageUrl,
    this.aiAnalysis,
  });

  factory MealPhoto.fromMap(String id, Map<String, dynamic> map) {
    return MealPhoto(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      mealType: MealType.values.firstWhere(
        (t) => t.name == map['mealType'],
        orElse: () => MealType.snack,
      ),
      imageUrl: map['imageUrl'] as String? ?? '',
      aiAnalysis: map['aiAnalysis'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'mealType': mealType.name,
      'imageUrl': imageUrl,
      'aiAnalysis': aiAnalysis,
    };
  }
}
