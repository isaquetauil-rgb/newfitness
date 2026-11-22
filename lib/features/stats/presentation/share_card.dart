import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/body_map/presentation/body_map_view.dart';
import 'package:newfitness/features/stats/logic/period_stats.dart';
import 'package:newfitness/features/workout/logic/workout_timing.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

/// Tamanho lógico do cartão (9:16). A imagem sai em 1080 × 1920.
const Size shareCardSize = Size(360, 640);
const double _pixelRatio = 3;

const _bg = Color(0xFF14171A);
const _bg2 = Color(0xFF1E2226);
const _green = Color(0xFF4CC98A);
const _text = Color(0xFFF5F6F7);
const _muted = Color(0xFF8A94A6);

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Moldura comum: fundo escuro, logo no topo e marca no rodapé.
class ShareCardFrame extends StatelessWidget {
  const ShareCardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material: o cartão pega a fonte do tema mesmo fora de um Scaffold.
    return SizedBox.fromSize(
      size: shareCardSize,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg2, _bg],
            ),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: _text, fontSize: 14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/app_icon_1024.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'NewFitness',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _green,
        ),
      ),
      Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    ],
  );
}

Widget _statGrid(List<_Stat> stats) => Wrap(
  spacing: 12,
  runSpacing: 12,
  children: [for (final s in stats) SizedBox(width: 144, child: s)],
);

Widget _recordList(List<PersonalRecord> records, {int max = 3}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final r in records.take(max))
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.emoji_events, size: 16, color: Color(0xFFF5C451)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                r.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    if (records.length > max)
      Text(
        '+ ${records.length - max} ${records.length - max == 1 ? 'recorde' : 'recordes'}',
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
  ],
);

Widget _miniMap(Map<MuscleRegion, double> intensities) => BodyMapView(
  intensities: intensities,
  color: _green,
  baseColor: const Color(0xFF2E343A),
  skinColor: const Color(0xFF3A4148),
);

/// Cartão de um treino finalizado.
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    super.key,
    required this.workout,
    required this.records,
    required this.muscles,
  });

  final Workout workout;
  final List<PersonalRecord> records;
  final Map<MuscleRegion, double> muscles;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(workout.date);
    final sets = workout.exercises.fold<int>(
      0,
      (sum, e) => sum + e.sets.where((s) => !s.isWarmup).length,
    );
    return ShareCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(_cap(date), style: const TextStyle(color: _muted)),
          const SizedBox(height: 18),
          _statGrid([
            _Stat(
              'duração',
              effectiveDurationSeconds(workout) > 0
                  ? formatHours(effectiveDurationSeconds(workout))
                  : '—',
            ),
            _Stat('volume', formatKg(workout.totalVolume)),
            _Stat(
              workout.exercises.length == 1 ? 'exercício' : 'exercícios',
              '${workout.exercises.length}',
            ),
            _Stat('séries', '$sets'),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _miniMap(muscles)),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              records.length == 1 ? 'Recorde de hoje' : 'Recordes de hoje',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _recordList(records),
          ],
        ],
      ),
    );
  }
}

/// Cartão de "Meu mês" / "Meu ano".
class PeriodShareCard extends StatelessWidget {
  const PeriodShareCard({super.key, required this.stats});

  final PeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final p = stats.period;
    final title = p.kind == PeriodKind.month
        ? _cap(DateFormat("MMMM 'de' y", 'pt_BR').format(p.start))
        : '${p.start.year}';
    final top = stats.topExercise;
    return ShareCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.kind == PeriodKind.month ? 'Meu mês' : 'Meu ano',
            style: const TextStyle(color: _muted, fontSize: 16),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          _statGrid([
            _Stat('treinos', '${stats.workouts}'),
            _Stat('horas treinando', formatHours(stats.totalSeconds)),
            _Stat('volume', formatKg(stats.volumeKg)),
            _Stat(
              stats.consecutiveWeeks == 1
                  ? 'semana seguida'
                  : 'semanas seguidas',
              '${stats.consecutiveWeeks}',
            ),
          ]),
          const SizedBox(height: 20),
          if (top != null) ...[
            const Text(
              'Exercício mais feito',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            Text(
              top.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'em ${top.workouts} ${top.workouts == 1 ? 'treino' : 'treinos'} · ${top.sets} séries',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            stats.records.isEmpty
                ? 'Nenhum recorde no período'
                : stats.records.length == 1
                ? '1 recorde batido'
                : '${stats.records.length} recordes batidos',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _recordList(stats.records, max: 5),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Transforma o cartão (dentro do [RepaintBoundary] de [key]) em PNG e abre
/// o compartilhar do sistema.
Future<void> shareCardImage(
  GlobalKey key, {
  required String fileName,
  String? text,
}) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: _pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes.buffer.asUint8List(),
          mimeType: 'image/png',
          name: fileName,
        ),
      ],
      fileNameOverrides: [fileName],
      text: text,
    ),
  );
}

/// Prévia do cartão, cabendo na tela, com o botão "Compartilhar".
class ShareCardPreview extends StatefulWidget {
  const ShareCardPreview({
    super.key,
    required this.card,
    required this.fileName,
    this.text,
  });

  final Widget card;
  final String fileName;
  final String? text;

  @override
  State<ShareCardPreview> createState() => _ShareCardPreviewState();
}

class _ShareCardPreviewState extends State<ShareCardPreview> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await shareCardImage(_key, fileName: widget.fileName, text: widget.text);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível compartilhar a imagem.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FittedBox(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RepaintBoundary(key: _key, child: widget.card),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            label: const Text('Compartilhar'),
          ),
        ),
      ],
    );
  }
}
