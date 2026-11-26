import 'package:flutter/material.dart';

import 'package:newfitness/shared/models/subscription.dart';

/// Textos e cores da mensalidade, usados no Financeiro, em Meus cartões e
/// em Contratos ativos.

/// "R$ 120,00"; "—" quando não há valor.
String formatCents(int? cents) {
  if (cents == null) return '—';
  return 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
}

String subscriptionStatusLabel(SubscriptionStatus status) => switch (status) {
  SubscriptionStatus.authorized => 'Em dia',
  SubscriptionStatus.pending => 'Pendente',
  SubscriptionStatus.paused => 'Pausada',
  SubscriptionStatus.cancelled => 'Cancelada',
  SubscriptionStatus.none => 'Sem assinatura',
};

Color subscriptionStatusColor(SubscriptionStatus status) => switch (status) {
  SubscriptionStatus.authorized => Colors.green,
  SubscriptionStatus.pending => Colors.orange,
  SubscriptionStatus.paused || SubscriptionStatus.cancelled => Colors.red,
  SubscriptionStatus.none => Colors.grey,
};

/// "25/11/2026".
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
