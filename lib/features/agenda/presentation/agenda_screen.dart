import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/agenda/logic/appointment_provider.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/appointment.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Agenda de compromissos (aula/treino presencial, avaliação...). Aluno vê
/// os próprios compromissos marcados pelo instrutor; instrutor vê a agenda
/// consolidada de todos os alunos e pode criar/cancelar.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _selectedDay = _dateOnly(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final uid = auth.user?.uid;
    final isInstructor = profile?.role == UserRole.instructor;
    final appointmentProvider = context.watch<AppointmentProvider>();

    if (uid == null || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final stream = isInstructor
        ? appointmentProvider.watchForInstructor(uid)
        : appointmentProvider.watchForStudent(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: StreamBuilder<List<Appointment>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final appointments = (snapshot.data ?? [])
              .where((a) => a.status != AppointmentStatus.canceled)
              .toList();
          final byDay = <DateTime, List<Appointment>>{};
          for (final a in appointments) {
            byDay.putIfAbsent(_dateOnly(a.start), () => []).add(a);
          }
          final selectedItems = byDay[_selectedDay] ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthCalendar(
                month: _month,
                selectedDay: _selectedDay,
                daysWithAppointments: byDay.keys.toSet(),
                onChangeMonth: _changeMonth,
                onSelectDay: (day) => setState(() => _selectedDay = day),
              ),
              const SizedBox(height: 20),
              Text(
                DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDay),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (selectedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Nenhum compromisso neste dia.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                for (final appointment in selectedItems)
                  _AppointmentTile(
                    appointment: appointment,
                    showStudentName: isInstructor,
                    onCancel: () =>
                        appointmentProvider.cancelAppointment(appointment),
                  ),
            ],
          );
        },
      ),
      floatingActionButton: isInstructor
          ? FloatingActionButton.extended(
              onPressed: () => _openNewAppointmentForm(context, profile.uid),
              icon: const Icon(Icons.add),
              label: const Text('Novo agendamento'),
            )
          : null,
    );
  }

  void _openNewAppointmentForm(BuildContext context, String instructorUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewAppointmentSheet(
        instructorUid: instructorUid,
        initialDay: _selectedDay,
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.daysWithAppointments,
    required this.onChangeMonth,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<DateTime> daysWithAppointments;
  final ValueChanged<int> onChangeMonth;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDay = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstDay.weekday % 7;
    final daysThisMonth = List.generate(
      daysInMonth,
      (i) => DateTime(month.year, month.month, i + 1),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onChangeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM \'de\' y', 'pt_BR').format(month),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onChangeMonth(1),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = daysThisMonth[index - leadingBlanks];
                final isToday = day == today;
                final isSelected = day == selectedDay;
                final hasAppointment = daysWithAppointments.contains(day);

                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: InkWell(
                    onTap: () => onSelectDay(day),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isToday
                            ? Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.15)
                            : null,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: hasAppointment || isToday
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                          if (hasAppointment)
                            Positioned(
                              bottom: 2,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.showStudentName,
    required this.onCancel,
  });

  final Appointment appointment;
  final bool showStudentName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      DateFormat('HH:mm').format(appointment.start),
      '${appointment.durationMinutes} min',
    ];
    if (showStudentName) subtitleParts.add(appointment.studentName);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(appointment.title),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: 'Cancelar',
          onPressed: () => _confirmCancel(context),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar compromisso?'),
        content: Text('"${appointment.title}" será marcado como cancelado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () {
              onCancel();
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar compromisso'),
          ),
        ],
      ),
    );
  }
}

class _NewAppointmentSheet extends StatefulWidget {
  const _NewAppointmentSheet({
    required this.instructorUid,
    required this.initialDay,
  });

  final String instructorUid;
  final DateTime initialDay;

  @override
  State<_NewAppointmentSheet> createState() => _NewAppointmentSheetState();
}

class _NewAppointmentSheetState extends State<_NewAppointmentSheet> {
  final _firestoreService = getIt<FirestoreService>();
  final _titleCtrl = TextEditingController(text: 'Treino presencial');
  final _durationCtrl = TextEditingController(text: '60');
  Map<String, dynamic>? _selectedStudent;
  late DateTime _date = widget.initialDay;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final student = _selectedStudent;
    if (student == null || _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha o aluno e dê um título.')),
      );
      return;
    }

    setState(() => _saving = true);
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final appointment = Appointment(
      id: '',
      instructorUid: widget.instructorUid,
      studentUid: student['uid'] as String,
      studentName: student['name'] as String? ?? '',
      title: _titleCtrl.text.trim(),
      start: start,
      durationMinutes: int.tryParse(_durationCtrl.text) ?? 60,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppointmentProvider>().saveAppointment(appointment);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Compromisso agendado')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível agendar. Verifique a conexão e se o aluno '
            'ainda está vinculado a você.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Novo agendamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.watchStudents(widget.instructorUid),
              builder: (context, snapshot) {
                final students = snapshot.data ?? [];
                return DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedStudent,
                  decoration: const InputDecoration(labelText: 'Aluno'),
                  items: [
                    for (final s in students)
                      DropdownMenuItem(
                        value: s,
                        child: Text(s['name'] as String? ?? ''),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedStudent = value),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duração (min)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }
}
