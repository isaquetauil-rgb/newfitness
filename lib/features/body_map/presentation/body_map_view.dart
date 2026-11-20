import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'package:newfitness/features/body_map/data/muscle_map_paths.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';

/// Um lado do corpo já convertido de SVG para [Path], com a área ocupada.
class _BodySide {
  _BodySide(Map<String, List<String>> source)
    : parts = {
        for (final e in source.entries)
          e.key: e.value.fold(Path(), (path, d) {
            path.addPath(parseSvgPathData(d), Offset.zero);
            return path;
          }),
      } {
    var rect = Rect.zero;
    var first = true;
    for (final p in parts.values) {
      final b = p.getBounds();
      rect = first ? b : rect.expandToInclude(b);
      first = false;
    }
    bounds = rect;
  }

  final Map<String, Path> parts;
  late final Rect bounds;

  // Convertidos uma vez só (são ~100 KB de SVG).
  static final Map<String, _BodySide> _cache = {};
  static _BodySide of(String key, Map<String, List<String>> source) =>
      _cache.putIfAbsent(key, () => _BodySide(source));
}

/// Cor de cada modo do mapa.
Color bodyMapColor(BodyMapMode mode, ColorScheme scheme) => switch (mode) {
  BodyMapMode.weekVolume => scheme.primary,
  BodyMapMode.recovering => Colors.deepOrange,
  BodyMapMode.forgotten => Colors.amber.shade700,
};

/// Corpo de frente e de costas, lado a lado, com cada músculo pintado
/// conforme [intensities] (0 a 1). Desenho: MuscleMap (MIT).
class BodyMapView extends StatelessWidget {
  const BodyMapView({
    super.key,
    required this.intensities,
    required this.color,
    this.female = false,
    this.baseColor,
    this.skinColor,
  });

  final Map<MuscleRegion, double> intensities;
  final Color color;
  final bool female;

  /// Cor dos músculos sem treino e das partes sem músculo (cabeça, mãos...).
  /// Padrão: cores do tema.
  final Color? baseColor;
  final Color? skinColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final front = female
        ? _BodySide.of('femaleFront', femaleFrontPaths)
        : _BodySide.of('maleFront', maleFrontPaths);
    final back = female
        ? _BodySide.of('femaleBack', femaleBackPaths)
        : _BodySide.of('maleBack', maleBackPaths);
    return Semantics(
      label: 'Mapa muscular, frente e costas',
      child: CustomPaint(
        painter: _BodyMapPainter(
          sides: [front, back],
          intensities: intensities,
          color: color,
          base: baseColor ?? scheme.surfaceContainerHighest,
          skin: skinColor ?? scheme.outlineVariant,
          outline: scheme.outline.withValues(alpha: 0.5),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BodyMapPainter extends CustomPainter {
  _BodyMapPainter({
    required this.sides,
    required this.intensities,
    required this.color,
    required this.base,
    required this.skin,
    required this.outline,
  });

  final List<_BodySide> sides;
  final Map<MuscleRegion, double> intensities;
  final Color color;
  final Color base;
  final Color skin;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 12.0;
    final slotWidth = (size.width - gap) / sides.length;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = outline;

    for (var i = 0; i < sides.length; i++) {
      final side = sides[i];
      final b = side.bounds;
      final scale = [
        slotWidth / b.width,
        size.height / b.height,
      ].reduce((a, c) => a < c ? a : c);
      final dx = i * (slotWidth + gap) + (slotWidth - b.width * scale) / 2;
      final dy = (size.height - b.height * scale) / 2;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.scale(scale);
      canvas.translate(-b.left, -b.top);
      stroke.strokeWidth = 1 / scale;
      side.parts.forEach((slug, path) {
        final region = MuscleRegion.fromSlug(slug);
        if (region == null) {
          fill.color = skin; // cabeça, mãos, pés, joelhos...
        } else {
          final t = intensities[region] ?? 0;
          fill.color = t <= 0 ? base : Color.lerp(base, color, t)!;
        }
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      });
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BodyMapPainter old) =>
      old.sides != sides ||
      old.color != color ||
      old.base != base ||
      !_sameMap(old.intensities, intensities);

  static bool _sameMap(
    Map<MuscleRegion, double> a,
    Map<MuscleRegion, double> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
