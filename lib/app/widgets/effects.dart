import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Efeitos visuais do app: abertura, entrada dos cartões, troca de aba e
/// confete. Todos respeitam "remover animações" do celular
/// (`MediaQuery.disableAnimations`): com ele ligado, nada se mexe.

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ---------------------------------------------------------------------------
// Entrada em cascata
// ---------------------------------------------------------------------------

/// Aparece subindo e clareando. [index] atrasa a entrada (cascata), até 8.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const duration = Duration(milliseconds: 380);
  static const step = Duration(milliseconds: 55);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // O atraso da cascata faz parte da própria animação (sem timer solto):
  // ela começa já, mas fica parada até a fração [_start].
  late final Duration _delay = FadeSlideIn.step * widget.index.clamp(0, 8);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _delay + FadeSlideIn.duration,
  );
  late final double _start =
      _delay.inMicroseconds / (_delay + FadeSlideIn.duration).inMicroseconds;
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(_start, 1, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Embrulha cada filho em [FadeSlideIn] com atraso crescente.
List<Widget> staggered(List<Widget> children) => [
  for (var i = 0; i < children.length; i++)
    FadeSlideIn(index: i, child: children[i]),
];

// ---------------------------------------------------------------------------
// Troca de aba
// ---------------------------------------------------------------------------

/// Esmaece a aba nova ao trocar de [index] (menu lateral / barra de abas).
class TabFade extends StatefulWidget {
  const TabFade({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void didUpdateWidget(TabFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
    child: widget.child,
  );
}

// ---------------------------------------------------------------------------
// Abertura do app
// ---------------------------------------------------------------------------

/// Abertura: o logo cresce com um quique, o nome aparece e a tela some,
/// revelando o app. Uma vez por abertura do app; não bloqueia o
/// carregamento (o app monta por baixo).
class AppIntroOverlay extends StatefulWidget {
  const AppIntroOverlay({super.key, required this.child});

  final Widget child;

  /// Já mostrou nesta abertura do app.
  static bool shown = false;

  @override
  State<AppIntroOverlay> createState() => _AppIntroOverlayState();
}

class _AppIntroOverlayState extends State<AppIntroOverlay>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1500);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _visible = !AppIntroOverlay.shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visible || _c.isAnimating || _c.isCompleted) return;
    AppIntroOverlay.shown = true;
    if (reduceMotion(context)) {
      _visible = false;
      return;
    }
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final logo = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.45, curve: Curves.elasticOut),
    );
    final name = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );
    final out = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.75, 1, curve: Curves.easeIn),
    );
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Opacity(
                opacity: 1 - out.value,
                child: ColoredBox(
                  color: scheme.surface,
                  child: Center(
                    child: Transform.scale(
                      scale: 1 + 0.15 * out.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: 0.4 + 0.6 * logo.value,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: 0.35 * logo.value.clamp(0, 1),
                                    ),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Transform.rotate(
                                angle: -math.pi / 4 * (1 - name.value),
                                child: Icon(
                                  Icons.fitness_center,
                                  size: 56,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Opacity(
                            opacity: name.value,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - name.value)),
                              child: Text(
                                'NewFitness',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: scheme.onSurface,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Confete
// ---------------------------------------------------------------------------

/// Solta confete por cima de tudo (ex.: treino salvo). Some sozinho.
void showConfetti(BuildContext context, {int pieces = 70}) {
  if (reduceMotion(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => ConfettiBurst(pieces: pieces, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 70, this.onDone});

  final int pieces;
  final VoidCallback? onDone;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _pieces = [
      for (var i = 0; i < widget.pieces; i++)
        _Piece(
          x: r.nextDouble(),
          // Sai de cima e um pouco antes, para cair em ondas.
          delay: r.nextDouble() * 0.35,
          speed: 0.7 + r.nextDouble() * 0.6,
          drift: (r.nextDouble() - 0.5) * 0.3,
          spin: (r.nextDouble() - 0.5) * 12,
          size: 6 + r.nextDouble() * 6,
          color: _colors[i % _colors.length],
          round: r.nextBool(),
        ),
    ];
    _c.forward().whenComplete(() => widget.onDone?.call());
  }

  static const _colors = [
    Color(0xFF4CC98B),
    Color(0xFFFFC107),
    Color(0xFF42A5F5),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _c.value),
      ),
    ),
  );
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * local * p.speed;
      final x =
          size.width * (p.x + p.drift * local) +
          math.sin(local * math.pi * 4 + p.x * 10) * 12;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
