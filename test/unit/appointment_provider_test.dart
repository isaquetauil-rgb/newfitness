import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/agenda/logic/appointment_provider.dart';
import 'package:newfitness/shared/models/appointment.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late AppointmentProvider provider;

  setUpAll(() {
    registerFallbackValue(
      Appointment(
        id: '',
        instructorUid: '',
        studentUid: '',
        studentName: '',
        title: '',
        start: DateTime(2024),
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = AppointmentProvider(firestoreService: firestoreService);
  });

  final appointment = Appointment(
    id: 'a1',
    instructorUid: 'instructor1',
    studentUid: 'student1',
    studentName: 'Maria',
    title: 'Avaliação física',
    start: DateTime(2024, 1, 10, 9),
  );

  test('watchForStudent delega ao FirestoreService', () async {
    final controller = StreamController<List<Appointment>>();
    when(() => firestoreService.watchAppointmentsForStudent('student1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchForStudent('student1').first;
    controller.add([appointment]);
    final result = await future;

    expect(result, [appointment]);
    await controller.close();
  });

  test('watchForInstructor delega ao FirestoreService', () async {
    final controller = StreamController<List<Appointment>>();
    when(() => firestoreService.watchAppointmentsForInstructor('instructor1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchForInstructor('instructor1').first;
    controller.add([appointment]);
    final result = await future;

    expect(result, [appointment]);
    await controller.close();
  });

  test('saveAppointment delega ao FirestoreService', () async {
    when(() => firestoreService.saveAppointment(any()))
        .thenAnswer((_) async {});

    await provider.saveAppointment(appointment);

    verify(() => firestoreService.saveAppointment(appointment)).called(1);
  });

  test('cancelAppointment salva o compromisso com status cancelado', () async {
    when(() => firestoreService.saveAppointment(any()))
        .thenAnswer((_) async {});

    await provider.cancelAppointment(appointment);

    final saved =
        verify(() => firestoreService.saveAppointment(captureAny()))
                .captured
                .single
            as Appointment;
    expect(saved.status, AppointmentStatus.canceled);
    expect(saved.id, appointment.id);
  });

  test('deleteAppointment delega ao FirestoreService', () async {
    when(() => firestoreService.deleteAppointment('student1', 'a1'))
        .thenAnswer((_) async {});

    await provider.deleteAppointment('student1', 'a1');

    verify(() => firestoreService.deleteAppointment('student1', 'a1'))
        .called(1);
  });
}
