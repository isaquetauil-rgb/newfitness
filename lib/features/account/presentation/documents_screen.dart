import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/account/presentation/account_widgets.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/finance/logic/subscription_labels.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Documentos: o que a pessoa já respondeu ou aceitou no app (questionário
/// de saúde, termo do treino livre, registro profissional) e acesso à
/// privacidade e à cópia dos próprios dados.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key, this.firestoreService});

  /// Para testes; no app vem do injetor.
  final FirestoreService? firestoreService;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final db = firestoreService ?? getIt<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (profile.role == UserRole.student)
                  AccountSection(
                    title: 'Saúde',
                    children: [_parq(context, profile)],
                  ),
                AccountSection(
                  title: 'Termos',
                  children: [
                    if (profile.role == UserRole.student)
                      _freeWorkoutTerm(profile),
                    AccountTile(
                      key: const ValueKey('doc-privacy'),
                      icon: Icons.privacy_tip_outlined,
                      title: 'Termos de uso e privacidade',
                      subtitle: 'Leia como seus dados são usados.',
                      onTap: () => context.push(AppRoutes.privacy),
                    ),
                  ],
                ),
                AccountSection(
                  title: 'Seus dados',
                  children: [
                    AccountTile(
                      key: const ValueKey('doc-export'),
                      icon: Icons.download_outlined,
                      title: 'Baixar uma cópia dos meus dados',
                      subtitle:
                          'Treinos, medidas e fotos num arquivo ZIP (em '
                          'Privacidade).',
                      onTap: () => context.push(AppRoutes.privacy),
                    ),
                  ],
                ),
                StreamBuilder<ProfessionalRequest?>(
                  stream: db.watchProfessionalRequest(profile.uid),
                  builder: (context, snap) => AccountSection(
                    title: 'Registro profissional',
                    children: [_professional(context, profile, snap.data)],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _parq(BuildContext context, UserProfile profile) {
    final parq = profile.parq;
    if (parq == null) {
      return AccountTile(
        key: const ValueKey('doc-parq'),
        icon: Icons.assignment_outlined,
        iconColor: Colors.orange,
        title: 'Questionário de saúde (PAR-Q)',
        subtitle: 'Ainda não respondido. Toque para responder.',
        onTap: () => context.push(AppRoutes.parq),
      );
    }
    return AccountTile(
      key: const ValueKey('doc-parq'),
      icon: Icons.assignment_turned_in_outlined,
      iconColor: parq.needsMedicalClearance ? Colors.orange : Colors.green,
      title: 'Questionário de saúde (PAR-Q)',
      subtitle:
          'Respondido em ${formatDate(parq.answeredDate)}'
          '${parq.needsMedicalClearance ? ' · procure liberação médica antes de treinar pesado' : ''}',
      onTap: () => context.push(AppRoutes.parq),
    );
  }

  Widget _freeWorkoutTerm(UserProfile profile) {
    final at = profile.freeWorkoutTermsAcceptedAt;
    return AccountTile(
      key: const ValueKey('doc-free-workout'),
      icon: at == null ? Icons.gavel_outlined : Icons.task_alt,
      iconColor: at == null ? Colors.grey : Colors.green,
      title: 'Termo do treino livre',
      subtitle: at == null
          ? 'Aparece na primeira vez que você começar um treino livre.'
          : 'Aceito em ${formatDate(DateTime.fromMillisecondsSinceEpoch(at))}',
    );
  }

  Widget _professional(
    BuildContext context,
    UserProfile profile,
    ProfessionalRequest? request,
  ) {
    if (profile.role != UserRole.student) {
      final kind = profile.role == UserRole.instructor ? 'CREF' : 'CRN';
      return AccountTile(
        key: const ValueKey('doc-professional'),
        icon: Icons.badge_outlined,
        iconColor: Colors.green,
        title: 'Registro $kind aprovado',
        subtitle: request?.registrationNumber.isNotEmpty == true
            ? '${request!.registrationNumber}'
                  '${request.registrationRegion.isEmpty ? '' : ' · ${request.registrationRegion}'}'
            : 'Você atende como profissional no app.',
      );
    }
    final (title, subtitle) = switch (request?.status) {
      null => (
        'É personal ou nutricionista?',
        'Envie seu CREF ou CRN para atender alunos pelo app.',
      ),
      ProfessionalRequestStatus.pending => (
        'Pedido em análise',
        'Enviado${request!.createdAt == null ? '' : ' em ${formatDate(request.createdAt!)}'}.',
      ),
      ProfessionalRequestStatus.rejected => (
        'Pedido não aprovado',
        request!.rejectionReason?.isNotEmpty == true
            ? request.rejectionReason!
            : 'Toque para ver os detalhes e enviar de novo.',
      ),
      ProfessionalRequestStatus.approved => (
        'Pedido aprovado',
        'Saia e entre de novo para ver o painel do profissional.',
      ),
    };
    return AccountTile(
      key: const ValueKey('doc-professional'),
      icon: Icons.badge_outlined,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(AppRoutes.professionalRequest),
    );
  }
}
