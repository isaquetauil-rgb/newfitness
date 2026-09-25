import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/appointment.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Compromissos da agenda (aula/treino presencial, avaliação...) marcados
/// pelo instrutor para um aluno — ver [Appointment].
class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<Appointment>> watchForStudent(String studentUid) {
    return _firestoreService.watchAppointmentsForStudent(studentUid);
  }

  Stream<List<Appointment>> watchForInstructor(String instructorUid) {
    return _firestoreService.watchAppointmentsForInstructor(instructorUid);
  }

  Future<void> saveAppointment(Appointment appointment) {
    return _firestoreService.saveAppointment(appointment);
  }

  Future<void> cancelAppointment(Appointment appointment) {
    return _firestoreService.saveAppointment(
      appointment.copyWith(status: AppointmentStatus.canceled),
    );
  }

  Future<void> deleteAppointment(String studentUid, String appointmentId) {
    return _firestoreService.deleteAppointment(studentUid, appointmentId);
  }
}
