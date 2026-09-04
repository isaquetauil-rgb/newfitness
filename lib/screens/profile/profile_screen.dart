import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestoreService = FirestoreService();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  void _syncFromProfile(UserProfile? profile) {
    if (_initialized || profile == null) return;
    _weightCtrl.text = profile.weightKg?.toString() ?? '';
    _heightCtrl.text = profile.heightCm?.toString() ?? '';
    _goalCtrl.text = profile.goalWeightKg?.toString() ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(UserProfile current) async {
    setState(() => _saving = true);
    final authProvider = context.read<AuthProvider>();
    final updated = current.copyWith(
      weightKg: double.tryParse(_weightCtrl.text),
      heightCm: double.tryParse(_heightCtrl.text),
      goalWeightKg: double.tryParse(_goalCtrl.text),
    );
    await _firestoreService.updateUserProfile(updated);
    if (!mounted) return;
    await authProvider.refreshProfile();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Perfil atualizado')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    _syncFromProfile(profile);

    return Scaffold(
      appBar: AppBar(
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
          ? const Center(child: CircularProgressIndicator())
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
                const SizedBox(height: 32),
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
}
