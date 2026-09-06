import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reminder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reminder_provider.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().requestNotificationPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final reminderProvider = context.watch<ReminderProvider>();

    if (uid != null) {
      // Garante que o provider está ouvindo o usuário certo.
      reminderProvider.listenTo(uid);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes')),
      body: uid == null
          ? const Center(child: Text('Faça login para configurar lembretes'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  icon: Icons.water_drop_outlined,
                  title: 'Água',
                  onAdd: () => _openReminderSheet(context, uid, ReminderType.water),
                ),
                const SizedBox(height: 8),
                if (reminderProvider.waterReminders.isEmpty)
                  const _EmptyHint(text: 'Nenhum lembrete de água ainda')
                else
                  for (final r in reminderProvider.waterReminders)
                    _ReminderTile(reminder: r, uid: uid),
                const SizedBox(height: 28),
                _SectionHeader(
                  icon: Icons.medication_outlined,
                  title: 'Suplementos',
                  onAdd: () => _openReminderSheet(context, uid, ReminderType.supplement),
                ),
                const SizedBox(height: 8),
                if (reminderProvider.supplementReminders.isEmpty)
                  const _EmptyHint(text: 'Nenhum lembrete de suplemento ainda')
                else
                  for (final r in reminderProvider.supplementReminders)
                    _ReminderTile(reminder: r, uid: uid),
              ],
            ),
    );
  }

  void _openReminderSheet(BuildContext context, String uid, ReminderType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReminderFormSheet(uid: uid, type: type),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onAdd;

  const _SectionHeader({required this.icon, required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final String uid;

  const _ReminderTile({required this.reminder, required this.uid});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ReminderProvider>();
    final subtitle = reminder.type == ReminderType.supplement && reminder.dosage != null
        ? reminder.dosage!
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(
          reminder.timeLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        title: Text(reminder.label),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.enabled,
              onChanged: (_) => provider.toggleReminder(uid, reminder),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => provider.deleteReminder(uid, reminder),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderFormSheet extends StatefulWidget {
  final String uid;
  final ReminderType type;

  const _ReminderFormSheet({required this.uid, required this.type});

  @override
  State<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends State<_ReminderFormSheet> {
  final _labelCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == ReminderType.water) {
      _labelCtrl.text = 'Beber um copo de água';
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final reminder = Reminder(
      id: '',
      type: widget.type,
      label: _labelCtrl.text.trim(),
      dosage: widget.type == ReminderType.supplement && _dosageCtrl.text.trim().isNotEmpty
          ? _dosageCtrl.text.trim()
          : null,
      hour: _time.hour,
      minute: _time.minute,
    );
    await context.read<ReminderProvider>().addOrUpdateReminder(widget.uid, reminder);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isSupplement = widget.type == ReminderType.supplement;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSupplement ? 'Novo lembrete de suplemento' : 'Novo lembrete de água',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: isSupplement ? 'Nome do suplemento' : 'Mensagem',
            ),
          ),
          if (isSupplement) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _dosageCtrl,
              decoration: const InputDecoration(
                labelText: 'Dosagem (opcional)',
                hintText: 'ex: 5g, 1 cápsula',
              ),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: const Text('Horário'),
            trailing: Text(
              _time.format(context),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onTap: _pickTime,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar lembrete'),
          ),
        ],
      ),
    );
  }
}
