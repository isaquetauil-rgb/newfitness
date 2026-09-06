import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';
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
    _weightCtrl.text = profile.weightKg?.toString() ?? '';
    _heightCtrl.text = profile.heightCm?.toString() ?? '';
    _goalCtrl.text = profile.goalWeightKg?.toString() ?? '';
    _initialized = true;
  }

  Future<void> _linkInstructor(UserProfile profile) async {
    final code = _linkCodeCtrl.text.trim();
    if (code.isEmpty) return;
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _linking = true);
    final instructor = await _firestoreService.findInstructorByCode(code);
    if (!mounted) return;
    if (instructor == null) {
      setState(() => _linking = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Código de instrutor inválido')),
      );
      return;
    }
    await _firestoreService.linkStudentToInstructor(
      student: profile,
      instructorId: instructor.uid,
    );
    if (!mounted) return;
    await authProvider.refreshProfile();
    setState(() => _linking = false);
    messenger.showSnackBar(
      SnackBar(content: Text('Vinculado a ${instructor.name}!')),
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

  Future<void> _save(UserProfile current) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final updated = current.copyWith(
      weightKg: double.tryParse(_weightCtrl.text),
      heightCm: double.tryParse(_heightCtrl.text),
      goalWeightKg: double.tryParse(_goalCtrl.text),
    );
    await _firestoreService.updateUserProfile(updated);
    if (mounted) {
      await authProvider.refreshProfile();
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil atualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
                if (profile.role == UserRole.instructor)
                  _InstructorCard(profile: profile)
                else if (profile.instructorId != null)
                  const _LinkedStudentCard()
                else
                  _LinkInstructorCard(
                    controller: _linkCodeCtrl,
                    linking: _linking,
                    onSubmit: () => _linkInstructor(profile),
                  ),
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
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Você está vinculado a um instrutor.')),
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
