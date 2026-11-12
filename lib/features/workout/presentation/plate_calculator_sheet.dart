import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/workout/logic/plate_calculator.dart';
import 'package:newfitness/shared/models/plate_setup.dart';

/// Abre a calculadora de anilhas para [weightKg]. Se o peso não fecha com as
/// anilhas da academia, [onUse] recebe o peso mais próximo quando o aluno
/// toca em "Usar".
Future<void> showPlateCalculator(
  BuildContext context, {
  required double weightKg,
  required ValueChanged<double> onUse,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PlateCalculatorSheet(weightKg: weightKg, onUse: onUse),
  );
}

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({
    super.key,
    required this.weightKg,
    required this.onUse,
  });

  final double weightKg;
  final ValueChanged<double> onUse;

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  bool _editing = false;
  late PlateSetup _draft;
  bool _saving = false;

  PlateSetup _setup(BuildContext context) =>
      context.watch<AuthProvider>().profile?.plateSetup ?? const PlateSetup();

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await context.read<AuthProvider>().savePlateSetup(_draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _editing
            ? _editor(context)
            : _result(context, loadPlates(widget.weightKg, setup), muted),
      ),
    );
  }

  Widget _result(BuildContext context, PlateLoad load, Color muted) {
    final grouped = load.grouped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Anilhas para ${plateKg(widget.weightKg)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('Barra de ${plateKg(load.barKg)}', style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        _BarDrawing(perSide: load.perSide),
        const SizedBox(height: 16),
        if (load.belowBar)
          Text(
            'O peso é menor que a barra vazia (${plateKg(load.barKg)}).',
            style: TextStyle(color: muted),
          )
        else if (grouped.isEmpty)
          const Text('Só a barra, sem anilhas.')
        else ...[
          const Text(
            'De cada lado',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final e in grouped.entries)
            Text(
              '${e.value} × ${plateKg(e.key)}',
              key: ValueKey('plate-${e.key}'),
            ),
        ],
        if (!load.exact && !load.belowBar) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Com as anilhas da sua academia não fecha '
              '${plateKg(widget.weightKg)}. O mais perto é '
              '${plateKg(load.achievedKg)}.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              widget.onUse(load.achievedKg);
              Navigator.of(context).pop();
            },
            child: Text('Usar ${plateKg(load.achievedKg)}'),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _draft =
                context.read<AuthProvider>().profile?.plateSetup ??
                const PlateSetup();
            _editing = true;
          }),
          icon: const Icon(Icons.tune),
          label: const Text('Barra e anilhas da minha academia'),
        ),
      ],
    );
  }

  Widget _editor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sua academia',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text('Barra', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final b in PlateSetup.commonBarsKg)
              ChoiceChip(
                label: Text(plateKg(b)),
                selected: _draft.barKg == b,
                onSelected: (_) =>
                    setState(() => _draft = _draft.copyWith(barKg: b)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Anilhas que tem',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in PlateSetup.allPlatesKg)
              FilterChip(
                key: ValueKey('plate-option-$p'),
                label: Text(plateKg(p)),
                selected: _draft.platesKg.contains(p),
                onSelected: (on) => setState(() {
                  final next = [..._draft.platesKg]..remove(p);
                  if (on) next.add(p);
                  next.sort((a, b) => b.compareTo(a));
                  _draft = _draft.copyWith(platesKg: next);
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving || _draft.platesKg.isEmpty ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Salvar no meu perfil'),
        ),
        TextButton(
          onPressed: () => setState(() => _editing = false),
          child: const Text('Voltar'),
        ),
      ],
    );
  }
}

/// Desenho simples: anilhas de um lado, a barra no meio e o outro lado
/// espelhado. A altura de cada anilha acompanha o peso.
class _BarDrawing extends StatelessWidget {
  const _BarDrawing({required this.perSide});

  final List<double> perSide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget plate(double kg) => Container(
      width: 12,
      height: 24 + 56 * (kg / 25).clamp(0.15, 1.0),
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    final left = [for (final p in perSide.reversed) plate(p)];
    final right = [for (final p in perSide) plate(p)];
    return SizedBox(
      height: 84,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...left,
          Expanded(child: Container(height: 8, color: colors.onSurfaceVariant)),
          ...right,
        ],
      ),
    );
  }
}
