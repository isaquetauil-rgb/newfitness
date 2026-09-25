enum AppointmentStatus { scheduled, completed, canceled }

AppointmentStatus _statusFromString(String? value) {
  switch (value) {
    case 'completed':
      return AppointmentStatus.completed;
    case 'canceled':
      return AppointmentStatus.canceled;
    default:
      return AppointmentStatus.scheduled;
  }
}

String _statusToString(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.completed:
      return 'completed';
    case AppointmentStatus.canceled:
      return 'canceled';
    case AppointmentStatus.scheduled:
      return 'scheduled';
  }
}

/// Um compromisso (aula/treino presencial, avaliação...) marcado pelo
/// instrutor para um aluno. Guardado em `users/{studentUid}/appointments/{id}`
/// — o aluno lê a própria subcoleção; o instrutor consolida a agenda de
/// todos os alunos com uma collection group query (ver
/// `FirestoreService.watchAppointmentsForInstructor`).
class Appointment {
  final String id;
  final String instructorUid;
  final String studentUid;
  final String studentName;
  final String title;
  final DateTime start;
  final int durationMinutes;
  final AppointmentStatus status;
  final String? notes;

  const Appointment({
    required this.id,
    required this.instructorUid,
    required this.studentUid,
    required this.studentName,
    required this.title,
    required this.start,
    this.durationMinutes = 60,
    this.status = AppointmentStatus.scheduled,
    this.notes,
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    return Appointment(
      id: id,
      instructorUid: map['instructorUid'] as String? ?? '',
      studentUid: map['studentUid'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      title: map['title'] as String? ?? 'Compromisso',
      start: DateTime.fromMillisecondsSinceEpoch(
        map['start'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      status: _statusFromString(map['status'] as String?),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'instructorUid': instructorUid,
      'studentUid': studentUid,
      'studentName': studentName,
      'title': title,
      'start': start.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'status': _statusToString(status),
      'notes': notes,
    };
  }

  Appointment copyWith({AppointmentStatus? status}) {
    return Appointment(
      id: id,
      instructorUid: instructorUid,
      studentUid: studentUid,
      studentName: studentName,
      title: title,
      start: start,
      durationMinutes: durationMinutes,
      status: status ?? this.status,
      notes: notes,
    );
  }
}
