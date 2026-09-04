/// Dados de perfil do usuário armazenados no Firestore.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final double? weightKg;
  final double? heightCm;
  final double? goalWeightKg;
  final DateTime? birthDate;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.weightKg,
    this.heightCm,
    this.goalWeightKg,
    this.birthDate,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      goalWeightKg: (map['goalWeightKg'] as num?)?.toDouble(),
      birthDate: map['birthDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['birthDate'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'goalWeightKg': goalWeightKg,
      'birthDate': birthDate?.millisecondsSinceEpoch,
    };
  }

  UserProfile copyWith({
    String? name,
    double? weightKg,
    double? heightCm,
    double? goalWeightKg,
    DateTime? birthDate,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}
