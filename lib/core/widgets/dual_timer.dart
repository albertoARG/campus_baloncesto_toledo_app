import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Cronómetro que cuenta hacia delante (cronómetro) o hacia atrás (cuenta
/// atrás). Reutilizable: [compact] lo hace más pequeño para incrustarlo.
class DualTimer extends StatefulWidget {
  final bool compact;
  const DualTimer({super.key, this.compact = false});

  @override
  State<DualTimer> createState() => _DualTimerState();
}

class _DualTimerState extends State<DualTimer> {
  bool _countdown = false;
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  Duration _target = Duration.zero;
  bool _finished = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _running => _sw.isRunning;

  Duration get _remaining {
    final r = _target - _sw.elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  Duration get _display => _countdown ? _remaining : _sw.elapsed;

  void _tick() {
    if (_countdown && _target > Duration.zero && _sw.elapsed >= _target) {
      _sw.stop();
      _ticker?.cancel();
      _ticker = null;
      _finished = true;
    }
    if (mounted) setState(() {});
  }

  void _start() {
    if (_countdown && _target == Duration.zero) return;
    _finished = false;
    _sw.start();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    setState(() {});
  }

  void _pause() {
    _sw.stop();
    _ticker?.cancel();
    _ticker = null;
    setState(() {});
  }

  void _reset() {
    _sw.stop();
    _sw.reset();
    _ticker?.cancel();
    _ticker = null;
    _finished = false;
    if (_countdown) _target = Duration.zero;
    setState(() {});
  }

  void _setMode(bool countdown) {
    _sw.stop();
    _sw.reset();
    _ticker?.cancel();
    _ticker = null;
    _finished = false;
    _target = Duration.zero;
    setState(() => _countdown = countdown);
  }

  String _fmt(Duration d, {bool cs = true}) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (!cs) return '$m:$s';
    final c = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$c';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final danger = _countdown &&
        (_finished ||
            (_running &&
                _target > Duration.zero &&
                _remaining <= const Duration(seconds: 10)));
    final color =
        _finished ? Colors.red : (danger ? Colors.orange.shade800 : primary);
    final canStart = !_countdown || _target > Duration.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false,
                label: Text('Cronómetro'),
                icon: Icon(Icons.timer_outlined)),
            ButtonSegment(
                value: true,
                label: Text('Cuenta atrás'),
                icon: Icon(Icons.hourglass_bottom)),
          ],
          selected: {_countdown},
          onSelectionChanged: (s) => _setMode(s.first),
        ),
        SizedBox(height: widget.compact ? 10 : 24),
        Text(
          _finished ? '¡Tiempo!' : _fmt(_display, cs: !_countdown),
          style: TextStyle(
            fontSize: widget.compact ? 48 : 76,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // Ajustar el tiempo de la cuenta atrás (solo parada).
        if (_countdown && !_running && !_finished) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final p in const [
                [10, '+10 s'],
                [30, '+30 s'],
                [60, '+1 min'],
                [300, '+5 min'],
              ])
                ActionChip(
                  label: Text(p[1] as String),
                  onPressed: () => setState(
                      () => _target += Duration(seconds: p[0] as int)),
                ),
            ],
          ),
        ],
        SizedBox(height: widget.compact ? 10 : 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _running ? _pause : (canStart ? _start : null),
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running ? 'Pausar' : 'Iniciar'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed:
                  (_sw.elapsed > Duration.zero || _target > Duration.zero)
                      ? _reset
                      : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Reiniciar'),
            ),
          ],
        ),
      ],
    );
  }
}
