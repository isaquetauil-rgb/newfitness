enum UserRole { student, instructor, nutritionist }

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.instructor:
      return 'instructor';
    case UserRole.nutritionist:
      return 'nutritionist';
    case UserRole.student:
      return 'student';
  }
}

UserRole userRoleFromString(String? value) {
  switch (value) {
    case 'instructor':
      return UserRole.instructor;
    case 'nutritionist':
      return UserRole.nutritionist;
    default:
      return UserRole.student;
  }
}

/// Dados de perfil do usuário armazenados no Firestore.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final double? weightKg;
  final double? heightCm;
  final double? goalWeightKg;
  final DateTime? birthDate;
  final UserRole role;
  final String? instructorId; // preenchido só para alunos, depois de vincular
  // Vínculo independente do instrutor — um aluno pode ter os dois, um só,
  // ou nenhum. A nutricionista fica isolada do domínio de treino (e
  // vice-versa): ver `firestore.rules` (nutrition_chat/nutrition_plans não
  // são legíveis pelo instrutor, training_plans não é legível pela
  // nutricionista).
  final String? nutritionistId;
  final String? inviteCode; // preenchido só para instrutores/nutricionistas
  final bool isPrivate;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.weightKg,
    this.heightCm,
    this.goalWeightKg,
    this.birthDate,
    this.role = UserRole.student,
    this.instructorId,
    this.nutritionistId,
    this.inviteCode,
    this.isPrivate = false,
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
      role: userRoleFromString(map['role'] as String?),
      instructorId: map['instructorId'] as String?,
      nutritionistId: map['nutritionistId'] as String?,
      inviteCode: map['inviteCode'] as String?,
      isPrivate: map['isPrivate'] as bool? ?? false,
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
      'role': userRoleToString(role),
      'instructorId': instructorId,
      'nutritionistId': nutritionistId,
      'inviteCode': inviteCode,
      'isPrivate': isPrivate,
    };
  }

  UserProfile copyWith({
    String? name,
    double? weightKg,
    double? heightCm,
    double? goalWeightKg,
    DateTime? birthDate,
    UserRole? role,
    String? instructorId,
    String? nutritionistId,
    String? inviteCode,
    bool? isPrivate,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      birthDate: birthDate ?? this.birthDate,
      role: role ?? this.role,
      instructorId: instructorId ?? this.instructorId,
      nutritionistId: nutritionistId ?? this.nutritionistId,
      inviteCode: inviteCode ?? this.inviteCode,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
