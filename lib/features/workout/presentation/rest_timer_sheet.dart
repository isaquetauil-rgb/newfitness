import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';

/// "1:05", "0:09".
String formatRest(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Abre o cronômetro de descanso. Se já há um descanso contando, mostra
/// ele; senão, deixa pronto para começar com [initialSeconds].
Future<void> showRestTimerSheet(
  BuildContext context, {
  int initialSeconds = 60,
}) {
  final controller = context.read<WorkoutProvider>().restTimer;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        RestTimerSheet(controller: controller, initialSeconds: initialSeconds),
  );
}

/// Redesenha a cada segundo enquanto há descanso contando e confere o fim
/// (inclusive ao voltar do segundo plano). O tempo vem do horário de fim do
/// controller, não deste relógio.
class _RestTicker extends StatefulWidget {
  const _RestTicker({required this.controller, required this.builder});

  final RestTimerController controller;
  final WidgetBuilder builder;

  @override
  State<_RestTicker> createState() => _RestTickerState();
}

class _RestTickerState extends State<_RestTicker> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChange);
    _syncTimer();
  }

  void _onChange() {
    if (!mounted) return;
    _syncTimer();
    setState(() {});
  }

  void _syncTimer() {
    if (widget.controller.isRunning) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!widget.controller.checkFinished() && mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.checkFinished();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChange);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Barra fixa no topo do treino com o tempo que falta, -15 s, +15 s e
/// Pular. Tocar nela abre o cronômetro completo. Some sem descanso ativo.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key, required this.controller});

  final RestTimerController controller;

  @override
  Widget build(BuildContext context) {
    return _RestTicker(
      controller: controller,
      builder: (context) {
        if (!controller.isActive) return const SizedBox.shrink();
        const ink = Color(0xFF14171A);
        final left = controller.remainingSeconds;
        final buttonStyle = TextButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(44, 40),
        );
        return Material(
          key: const ValueKey('rest-bar'),
          color: Theme.of(context).colorScheme.primary,
          child: InkWell(
            onTap: () => showRestTimerSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    controller.isPaused
                        ? Icons.pause_circle_outline
                        : Icons.timer_outlined,
                    color: ink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${controller.isPaused ? 'Pausado' : 'Descanso'} '
                          '${formatRest(left)}',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: controller.progress,
                          color: ink,
                          backgroundColor: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.adjust(-15),
                    style: buttonStyle,
                    child: const Text('-15s'),
                  ),
                  TextButton(
                    onPressed: () => controller.adjust(15),
                    style: buttonStyle,
                    child: const Text('+15s'),
                  ),
                  TextButton(
                    onPressed: controller.skip,
                    style: buttonStyle,
                    child: const Text('Pular'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RestTimerSheet extends StatefulWidget {
  const RestTimerSheet({
    super.key,
    required this.controller,
    this.initialSeconds = 60,
  });

  final RestTimerController controller;
  final int initialSeconds;

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> {
  /// Duração escolhida para quando não há descanso contando.
  late int _selected = widget.initialSeconds;

  static const List<int> _presets = [30, 60, 90, 120];

  RestTimerController get _c => widget.controller;

  String _mmss(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  void _choose(int seconds) {
    setState(() => _selected = seconds);
    if (_c.isActive) _c.start(seconds);
  }

  void _playPause() {
    if (_c.isRunning) {
      _c.pause();
    } else if (_c.isPaused) {
      _c.resume();
    } else {
      _c.start(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RestTicker(
      controller: _c,
      builder: (context) {
        final active = _c.isActive;
        final remaining = active ? _c.remainingSeconds : _selected;
        final total = active ? _c.totalSeconds : _selected;
        final progress = total == 0 ? 0.0 : remaining / total;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Descanso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                width: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0, 1),
                        strokeWidth: 10,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Text(
                      _mmss(remaining),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in _presets)
                    ChoiceChip(
                      label: Text('${p}s'),
                      selected: (active ? _c.totalSeconds : _selected) == p,
                      onSelected: (_) => _choose(p),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: active ? () => _c.adjust(-15) : null,
                    tooltip: 'Menos 15 segundos',
                    icon: const Text('-15s'),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: _playPause,
                    tooltip: _c.isRunning ? 'Pausar' : 'Começar',
                    icon: Icon(_c.isRunning ? Icons.pause : Icons.play_arrow),
                    iconSize: 32,
                    padding: const EdgeInsets.all(20),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    onPressed: active ? () => _c.adjust(15) : null,
                    tooltip: 'Mais 15 segundos',
                    icon: const Text('+15s'),
                  ),
                ],
              ),
              if (active) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _c.skip();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Pular descanso'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Opções do cronômetro nas configurações: início automático, som e
/// vibração. Salvas no aparelho e aplicadas na hora.
class RestTimerSettingsTiles extends StatelessWidget {
  const RestTimerSettingsTiles({super.key, this.prefs});

  /// Para testes; no app usa o [LocalPrefs] registrado.
  final LocalPrefs? prefs;

  LocalPrefs? get _prefs =>
      prefs ??
      (getIt.isRegistered<LocalPrefs>() && getIt.isReadySync<LocalPrefs>()
          ? getIt<LocalPrefs>()
          : null);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<WorkoutProvider>().restTimer;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.settings;
        final prefs = _prefs;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              key: const ValueKey('rest-auto-start'),
              secondary: const Icon(Icons.timer_outlined),
              title: const Text('Descanso automático'),
              subtitle: const Text('Começa ao marcar uma série como feita'),
              value: s.autoStart,
              onChanged: (v) {
                controller.updateSettings(
                  controller.settings.copyWith(autoStart: v),
                );
                prefs?.setRestAutoStart(v);
              },
            ),
            SwitchListTile(
              key: const ValueKey('rest-sound'),
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Som no fim do descanso'),
              value: s.sound,
              onChanged: (v) {
                controller.updateSettings(
                  controller.settings.copyWith(sound: v),
                );
                prefs?.setRestSound(v);
              },
            ),
            SwitchListTile(
              key: const ValueKey('rest-vibration'),
              secondary: const Icon(Icons.vibration),
              title: const Text('Vibrar no fim do descanso'),
              value: s.vibration,
              onChanged: (v) {
                controller.updateSettings(
                  controller.settings.copyWith(vibration: v),
                );
                prefs?.setRestVibration(v);
              },
            ),
          ],
        );
      },
    );
  }
}
