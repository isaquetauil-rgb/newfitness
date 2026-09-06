enum UserRole { student, instructor }

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
  final String? inviteCode; // preenchido só para instrutores

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
    this.inviteCode,
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
      role: (map['role'] as String?) == 'instructor' ? UserRole.instructor : UserRole.student,
      instructorId: map['instructorId'] as String?,
      inviteCode: map['inviteCode'] as String?,
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
      'role': role == UserRole.instructor ? 'instructor' : 'student',
      'instructorId': instructorId,
      'inviteCode': inviteCode,
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
    String? inviteCode,
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
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}
