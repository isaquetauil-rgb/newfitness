import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/progress/logic/evolution_summary.dart';
import 'package:newfitness/features/progress/logic/physical_assessment_provider.dart';
import 'package:newfitness/shared/models/physical_assessment.dart';

/// Abre o formulário de avaliação. Sem [existing], cria uma nova (com a
/// altura mais recente pré-preenchida via [suggestedHeightCm]); com
/// [existing], edita aquela avaliação.
Future<void> showAssessmentForm(
  BuildContext context, {
  required String userId,
  required String recordedBy,
  PhysicalAssessment? existing,
  double? suggestedHeightCm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Formulário longo: sem isso a folha sobe por baixo da barra de status.
    useSafeArea: true,
    builder: (_) => AssessmentFormSheet(
      userId: userId,
      recordedBy: recordedBy,
      existing: existing,
      suggestedHeightCm: suggestedHeightCm,
    ),
  );
}

class AssessmentFormSheet extends StatefulWidget {
  const AssessmentFormSheet({
    super.key,
    required this.userId,
    required this.recordedBy,
    this.existing,
    this.suggestedHeightCm,
  });

  final String userId;
  final String recordedBy;
  final PhysicalAssessment? existing;
  final double? suggestedHeightCm;

  @override
  State<AssessmentFormSheet> createState() => _AssessmentFormSheetState();
}

class _AssessmentFormSheetState extends State<AssessmentFormSheet> {
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late final _weightCtrl = _ctrl(widget.existing?.weightKg);
  late final _heightCtrl = _ctrl(
    widget.existing != null
        ? widget.existing!.heightCm
        : widget.suggestedHeightCm,
  );
  late final _fatCtrl = _ctrl(widget.existing?.bodyFatPercent);
  late final _muscleCtrl = _ctrl(widget.existing?.muscleMassKg);
  late String? _fatMethod = widget.existing?.bodyFatMethod;
  late final _notesCtrl = TextEditingController(
    text: widget.existing?.notes ?? '',
  );

  /// Campos do formulário: as 14 medidas atuais mais qualquer chave antiga/
  /// desconhecida já presente na avaliação em edição (para não perdê-la).
  late final List<String> _measurementKeys = [
    ...BodyMeasurement.all,
    for (final k in widget.existing?.measurementsCm.keys ?? const <String>[])
      if (!BodyMeasurement.all.contains(k)) k,
  ];
  late final Map<String, TextEditingController> _measurementCtrls = {
    for (final key in _measurementKeys)
      key: _ctrl(widget.existing?.measurementsCm[key]),
  };
  bool _saving = false;

  static TextEditingController _ctrl(double? value) => TextEditingController(
    text: value == null ? '' : formatMetric(value, decimals: 2),
  );

  static double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  @override
  void dispose() {
    for (final c in [
      _weightCtrl,
      _heightCtrl,
      _fatCtrl,
      _muscleCtrl,
      _notesCtrl,
      ..._measurementCtrls.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _validate(double? weight, double? height, double? fat) {
    if (weight != null && weight > 500) return 'Peso inválido.';
    if (height != null && (height < 50 || height > 260)) {
      return 'Altura inválida (em cm, ex.: 175).';
    }
    if (fat != null && fat >= 100) return '% de gordura inválido.';
    return null;
  }

  Future<void> _save() async {
    final weight = _parse(_weightCtrl);
    final height = _parse(_heightCtrl);
    final fat = _parse(_fatCtrl);
    final muscle = _parse(_muscleCtrl);
    final measurements = <String, double>{
      for (final entry in _measurementCtrls.entries)
        entry.key: ?_parse(entry.value),
    };
    final notes = _notesCtrl.text.trim();

    final messenger = ScaffoldMessenger.of(context);
    final error = _validate(weight, height, fat);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final draft = PhysicalAssessment(
      id: widget.existing?.id ?? '',
      userId: widget.userId,
      date: _date,
      weightKg: weight,
      heightCm: height,
      bodyFatPercent: fat,
      bodyFatMethod: fat == null ? null : _fatMethod,
      muscleMassKg: muscle,
      measurementsCm: measurements,
      recordedBy: widget.recordedBy,
      notes: notes.isEmpty ? null : notes,
    );
    if (draft.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Preencha ao menos um valor (peso, altura ou medida).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<PhysicalAssessmentProvider>();
    final auth = context.read<AuthProvider>();
    try {
      if (widget.existing != null) {
        await provider.updateAssessment(widget.existing!, draft);
      } else {
        await provider.addAssessment(
          draft,
          authorUid: auth.user!.uid,
          authorName: auth.profile?.name,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a avaliação.')),
      );
    }
  }

  Widget _numberField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
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
            Text(
              widget.existing == null ? 'Nova avaliação' : 'Editar avaliação',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Todos os campos são opcionais — preencha só o que foi medido.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _numberField(_weightCtrl, 'Peso (kg)')),
                const SizedBox(width: 12),
                Expanded(child: _numberField(_heightCtrl, 'Altura (cm)')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_fatCtrl, '% de gordura')),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(_muscleCtrl, 'Massa muscular (kg)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _fatMethod,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Método da medição de gordura',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Não informado'),
                ),
                for (final m in BodyFatMethod.all)
                  DropdownMenuItem(
                    value: m,
                    child: Text(BodyFatMethod.labelOf(m)),
                  ),
              ],
              onChanged: (v) => setState(() => _fatMethod = v),
            ),
            const SizedBox(height: 20),
            const Text(
              'Medidas (cm)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3,
              children: [
                for (final key in _measurementKeys)
                  _numberField(
                    _measurementCtrls[key]!,
                    BodyMeasurement.labelOf(key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                    : const Text('Salvar avaliação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
