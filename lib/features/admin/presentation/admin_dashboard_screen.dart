import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/features/admin/logic/admin_provider.dart';

/// Painel de administração — visível só para o dono do app
/// (`AuthProvider.isAdmin`). Mostra estatísticas gerais e atalhos para
/// gerenciar usuários e a biblioteca de exercícios.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = context.read<AdminProvider>().loadStats();
  }

  void _reload() {
    setState(() {
      _statsFuture = context.read<AdminProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Painel admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar estatísticas',
            onPressed: _reload,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<AdminStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Não foi possível carregar as estatísticas.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final stats = snapshot.data!;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(label: 'Usuários', value: '${stats.totalUsers}'),
                  _StatCard(label: 'Alunos', value: '${stats.totalStudents}'),
                  _StatCard(
                    label: 'Instrutores',
                    value: '${stats.totalInstructors}',
                  ),
                  _StatCard(
                    label: 'Nutricionistas',
                    value: '${stats.totalNutritionists}',
                  ),
                  _StatCard(
                    label: 'Exercícios',
                    value: '${stats.totalExercises}',
                  ),
                  _StatCard(
                    label: 'Treinos registrados',
                    value: '${stats.totalWorkoutsLogged}',
                  ),
                  _StatCard(
                    label: 'Assinaturas ativas',
                    value: '${stats.activeSubscriptions}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Usuários'),
              subtitle: const Text('Ver todos, promover ou rebaixar papel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminUsers),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Biblioteca de exercícios'),
              subtitle: const Text('Adicionar, editar ou remover exercícios'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminExercises),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Taxonomia de exercícios'),
              subtitle: const Text('Grupos musculares e equipamentos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminTaxonomy),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Pedidos de profissional'),
              subtitle: const Text(
                'Aprovar ou recusar personal (CREF) e nutricionista (CRN)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminProfessionalRequests),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
