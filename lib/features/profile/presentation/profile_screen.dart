import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/theme/theme_provider.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/core/constants/admin_config.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/email_verification_notice.dart';
import 'package:newfitness/features/profile/presentation/manage_link_sheet.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestoreService = getIt<FirestoreService>();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _linkCodeCtrl = TextEditingController();
  bool _saving = false;
  bool _linking = false;
  bool _initialized = false;

  void _syncFromProfile(UserProfile? profile) {
    if (_initialized || profile == null) return;
    String fmt(double? v) =>
        v == null ? '' : v.toString().replaceFirst(RegExp(r'\.0$'), '');
    _weightCtrl.text = fmt(profile.weightKg);
    _heightCtrl.text = fmt(profile.heightCm);
    _goalCtrl.text = fmt(profile.goalWeightKg);
    _initialized = true;
  }

  Future<void> _linkInstructor(UserProfile profile) async {
    final code = _linkCodeCtrl.text.trim();
    if (code.isEmpty) return;
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _linking = true);
    // Valida e grava o vínculo no servidor (Cloud Function) — o app nunca
    // escreve `instructorId` diretamente, ver `firestore.rules`.
    final instructorName = await authProvider.linkToInstructor(code);
    if (!mounted) return;
    setState(() => _linking = false);
    if (instructorName == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Código de instrutor inválido',
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Vinculado a $instructorName!')),
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _goalCtrl.dispose();
    _linkCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Text(
          'Vamos enviar um link de redefinição de senha para ${profile.email}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.resetPassword(profile.email);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'E-mail enviado! Confira sua caixa de entrada.'
              : (auth.errorMessage ?? 'Não foi possível enviar o e-mail.'),
        ),
      ),
    );
  }

  void _inviteFriends() {
    const message =
        'Baixe o NewFitness e comece a treinar com acompanhamento '
        'profissional! 💪';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Indicar amigos'),
        content: const Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Texto copiado')));
            },
            child: const Text('Copiar texto'),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: ownerEmail,
      query: 'subject=Suporte NewFitness',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o e-mail.')),
      );
    }
  }

  Future<void> _save(UserProfile current) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Aceita vírgula (teclado pt-BR). Antes "75,5" virava null e o valor
    // era ignorado em silêncio, mesmo com a mensagem "Perfil atualizado".
    double? parse(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));
    final invalid = [
      _weightCtrl,
      _heightCtrl,
      _goalCtrl,
    ].any((c) => c.text.trim().isNotEmpty && parse(c) == null);
    if (invalid) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Use apenas números (ex.: 75,5).')),
      );
      return;
    }
    setState(() => _saving = true);
    final updated = current.copyWith(
      weightKg: parse(_weightCtrl),
      heightCm: parse(_heightCtrl),
      goalWeightKg: parse(_goalCtrl),
    );
    try {
      await _firestoreService.updateUserProfile(updated);
      await authProvider.refreshProfile();
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil atualizado')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o perfil.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final profile = auth.profile;
    _syncFromProfile(profile);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: profile == null
          ? _buildProfileMissingBody(auth)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    profile.email,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 20),
                // Qualquer papel: a IA (e, para alunos, o pedido de
                // profissional) exige o e-mail verificado.
                if (!auth.isEmailVerified) ...[
                  const EmailVerificationNotice(
                    reason:
                        'Para usar a IA e os recursos que pedem e-mail '
                        'confirmado',
                  ),
                  const SizedBox(height: 20),
                ],
                _WeeklyProgressCard(uid: profile.uid),
                const SizedBox(height: 20),
                if (profile.role == UserRole.instructor)
                  _InstructorCard(profile: profile)
                // Nutricionista não se vincula a instrutor (a Function
                // recusa) — antes via o cartão de vínculo de aluno.
                else if (profile.role == UserRole.nutritionist)
                  const SizedBox.shrink()
                else if (profile.instructorId != null)
                  const _LinkedStudentCard()
                else
                  _LinkInstructorCard(
                    controller: _linkCodeCtrl,
                    linking: _linking,
                    onSubmit: () => _linkInstructor(profile),
                  ),
                if (profile.role == UserRole.student) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: const Text('Sou profissional'),
                      subtitle: const Text(
                        'Personal (CREF) ou nutricionista (CRN)? Peça a '
                        'aprovação.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.professionalRequest),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Peso atual (kg)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: 'ex: 75.5'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Altura (cm)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _heightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: 'ex: 175'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Meta de peso (kg)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _goalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: 'ex: 70'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(profile),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar alterações'),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Configurações',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Alterar senha'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _changePassword(profile),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.credit_card_outlined),
                        title: const Text('Meus cartões'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.myCards),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Contratos ativos'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.activeContracts),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: const Text('Documentos'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.documents),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Modo escuro'),
                        value: themeProvider.isDarkMode,
                        onChanged: themeProvider.setDarkMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _inviteFriends,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Indicar amigos'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _contactSupport,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Entrar em contato'),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileMissingBody(AuthProvider auth) {
    if (auth.profileError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              auth.profileError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: auth.isLoadingProfile ? null : auth.retryLoadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card "Meu progresso": 7 bolinhas da semana atual (segunda a domingo),
/// marcadas conforme há treino registrado naquele dia. Calculado em cima
/// de `WorkoutProvider.watchHistory` — sem coleção nova no Firestore.
class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.uid});

  final String uid;

  static const _weekdayLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    // `read` (não `watch`): o card só precisa do histórico salvo, e observar o
    // provider recriava a consulta a cada série digitada no treino em
    // andamento.
    final workoutProvider = context.read<WorkoutProvider>();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.progressCalendar),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<Workout>>(
            stream: workoutProvider.watchHistory(uid),
            builder: (context, snapshot) {
              final workouts = snapshot.data ?? [];
              final workoutDays = workouts
                  .map((w) => _dateOnly(w.date))
                  .toSet();

              final now = DateTime.now();
              final monday = _dateOnly(
                now.subtract(Duration(days: now.weekday - 1)),
              );
              final week = List.generate(
                7,
                (i) => monday.add(Duration(days: i)),
              );
              final doneCount = week
                  .where((d) => workoutDays.contains(d))
                  .length;
              final percent = ((doneCount / 7) * 100).round();

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined),
                            const SizedBox(width: 8),
                            const Text(
                              'Meu progresso',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (int i = 0; i < 7; i++)
                              _DayDot(
                                label: _weekdayLabels[i],
                                done: workoutDays.contains(week[i]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$doneCount de 7 dias concluídos',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.circle_outlined,
          color: done
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade400,
          size: 22,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _InstructorCard extends StatelessWidget {
  final UserProfile profile;

  const _InstructorCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_gymnastics),
                const SizedBox(width: 8),
                const Text(
                  'Você é instrutor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Código: ', style: TextStyle(color: Colors.grey.shade600)),
                Text(
                  profile.inviteCode ?? '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: profile.inviteCode == null
                      ? null
                      : () {
                          Clipboard.setData(
                            ClipboardData(text: profile.inviteCode!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código copiado')),
                          );
                        },
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.instructor),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Ver meus alunos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedStudentCard extends StatelessWidget {
  const _LinkedStudentCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Expanded(child: Text('Você está vinculado a um instrutor.')),
            TextButton(
              onPressed: () =>
                  showManageLinkSheet(context, LinkedProfessional.instructor),
              child: const Text('Gerenciar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkInstructorCard extends StatelessWidget {
  final TextEditingController controller;
  final bool linking;
  final VoidCallback onSubmit;

  const _LinkInstructorCard({
    required this.controller,
    required this.linking,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vincular a um instrutor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Código do instrutor',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: linking ? null : onSubmit,
                  child: linking
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Vincular'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
