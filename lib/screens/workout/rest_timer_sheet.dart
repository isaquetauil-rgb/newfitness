import 'dart:async';

import 'package:flutter/material.dart';

/// Abre uma folha inferior (bottom sheet) com um cronômetro regressivo
/// para o descanso entre séries.
Future<void> showRestTimerSheet(
  BuildContext context, {
  int initialSeconds = 60,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => RestTimerSheet(initialSeconds: initialSeconds),
  );
}

class RestTimerSheet extends StatefulWidget {
  final int initialSeconds;

  const RestTimerSheet({super.key, this.initialSeconds = 60});

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> {
  late int _totalSeconds;
  late int _remaining;
  Timer? _timer;
  bool _running = false;

  static const List<int> _presets = [30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.initialSeconds;
    _remaining = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        setState(() => _running = false);
        return;
      }
      setState(() => _remaining--);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remaining = seconds;
      _running = false;
    });
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _totalSeconds == 0 ? 0.0 : _remaining / _totalSeconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Descanso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                Text(
                  _format(_remaining),
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
            children: _presets
                .map((p) => ChoiceChip(
                      label: Text('${p}s'),
                      selected: _totalSeconds == p,
                      onSelected: (_) => _reset(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => _reset(_totalSeconds),
                icon: const Icon(Icons.replay),
                iconSize: 28,
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                onPressed: _running ? _pause : _start,
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                iconSize: 32,
                padding: const EdgeInsets.all(20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
