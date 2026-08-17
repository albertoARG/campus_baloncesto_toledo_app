import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/matches_providers.dart';
import '../../data/models/live_match_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class LiveMatchScreen extends ConsumerWidget {
  final String matchId;
  const LiveMatchScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene viva la suscripción del stream.
    final asyncList = ref.watch(matchesStreamProvider);
    final match = ref.watch(singleMatchProvider(matchId));
    final role = ref.watch(currentUserProfileProvider).value?.role ?? 'visitante';
    final canManage = role == 'admin' || role == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Marcador en directo'),
      ),
      body: asyncList.when(
        data: (_) {
          if (match == null) {
            return const Center(child: Text('El partido ya no existe.'));
          }
          return _Scoreboard(match: match, canManage: canManage);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _Scoreboard extends ConsumerStatefulWidget {
  final LiveMatchModel match;
  final bool canManage;
  const _Scoreboard({required this.match, required this.canManage});

  @override
  ConsumerState<_Scoreboard> createState() => _ScoreboardState();
}

class _ScoreboardState extends ConsumerState<_Scoreboard> {
  // ---- Cronómetro (local a este dispositivo) ----
  static const int _defaultSeconds = 10 * 60; // 10:00 por defecto
  int _remaining = _defaultSeconds;
  int _lastSet = _defaultSeconds;
  bool _running = false;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
    } else {
      if (_remaining <= 0) return;
      setState(() => _running = true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining <= 1) {
          _ticker?.cancel();
          setState(() {
            _remaining = 0;
            _running = false;
          });
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _remaining = _lastSet;
    });
  }

  Future<void> _editTime() async {
    _ticker?.cancel();
    setState(() => _running = false);
    final minCtrl = TextEditingController(text: (_remaining ~/ 60).toString());
    final secCtrl = TextEditingController(text: (_remaining % 60).toString().padLeft(2, '0'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Poner tiempo'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Min'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: TextField(
                controller: secCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Seg'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aceptar')),
        ],
      ),
    );
    if (ok == true) {
      final m = int.tryParse(minCtrl.text) ?? 0;
      final s = (int.tryParse(secCtrl.text) ?? 0).clamp(0, 59);
      final total = (m * 60 + s).clamp(0, 99 * 60 + 59);
      setState(() {
        _remaining = total;
        _lastSet = total;
      });
    }
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---- Marcador / faltas ----
  Future<void> _set(Map<String, dynamic> data) async {
    try {
      await ref.read(matchesRepositoryProvider).update(widget.match.id, data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _winnerText(LiveMatchModel m) {
    if (m.ganador != null && m.ganador!.isNotEmpty) return m.ganador!;
    if (m.score1 > m.score2) return m.team1Name;
    if (m.score2 > m.score1) return m.team2Name;
    return 'Empate';
  }

  Future<void> _finalize() async {
    final m = widget.match;
    String selected = m.score1 > m.score2
        ? m.team1Name
        : m.score2 > m.score1
            ? m.team2Name
            : 'Empate';
    final options = [m.team1Name, m.team2Name, 'Empate'];
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Finalizar partido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resultado: ${m.score1} - ${m.score2}'),
              const SizedBox(height: 8),
              const Text('¿Quién ha ganado?', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final opt in options)
                RadioListTile<String>(
                  value: opt,
                  groupValue: selected,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(opt),
                  onChanged: (v) => setLocal(() => selected = v!),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(c, selected),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      _ticker?.cancel();
      if (mounted) setState(() => _running = false);
      await _set({'estado': 'finalizado', 'ganador': result});
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final canManage = widget.canManage;
    final live = !match.finalizado;
    final editable = canManage && live;

    return Column(
      children: [
        if (live)
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'EN JUEGO',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          )
        else
          Container(
            width: double.infinity,
            color: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              _winnerText(match) == 'Empate'
                  ? 'FINAL · Empate'
                  : 'FINAL · 🏆 Ganador: ${_winnerText(match)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),

        // ---- Cronómetro (solo para quien gestiona y con el partido en juego) ----
        if (canManage && live) _buildTimerBar(context),

        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _TeamColumn(
                  name: match.team1Name,
                  score: match.score1,
                  fouls: match.fouls1,
                  editable: editable,
                  onPoints: (d) => _set({'score1': (match.score1 + d).clamp(0, 9999)}),
                  onFoul: (d) => _set({'fouls1': (match.fouls1 + d).clamp(0, 99)}),
                ),
              ),
              Container(
                width: 1,
                color: Colors.grey.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(vertical: 24),
              ),
              Expanded(
                child: _TeamColumn(
                  name: match.team2Name,
                  score: match.score2,
                  fouls: match.fouls2,
                  editable: editable,
                  onPoints: (d) => _set({'score2': (match.score2 + d).clamp(0, 9999)}),
                  onFoul: (d) => _set({'fouls2': (match.fouls2 + d).clamp(0, 99)}),
                ),
              ),
            ],
          ),
        ),
        if (canManage)
          Padding(
            padding: const EdgeInsets.all(16),
            child: live
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.flag),
                    label: const Text('Finalizar partido'),
                    onPressed: _finalize,
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Reanudar partido'),
                    onPressed: () => _set({'estado': 'en_juego', 'ganador': null}),
                  ),
          ),
        if (!canManage)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Actualización en tiempo real', style: TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _buildTimerBar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Reiniciar',
            icon: const Icon(Icons.replay),
            onPressed: _resetTimer,
          ),
          // Tocar el tiempo para ponerlo a mano
          InkWell(
            onTap: _editTime,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(_remaining),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _remaining == 0 ? Colors.red : primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: _toggleTimer,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
              backgroundColor: _running ? Colors.orange : Colors.green,
            ),
            child: Icon(_running ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final int score;
  final int fouls;
  final bool editable;
  final void Function(int delta) onPoints;
  final void Function(int delta) onFoul;
  const _TeamColumn({
    required this.name,
    required this.score,
    required this.fouls,
    required this.editable,
    required this.onPoints,
    required this.onFoul,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              '$score',
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: primary),
            ),
          ),
          const SizedBox(height: 4),
          if (!editable)
            Text('Faltas: $fouls', style: const TextStyle(color: Colors.grey)),
          if (editable) ...[
            const SizedBox(height: 14),
            _sectionLabel('PUNTOS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final d in [1, 2, 3])
                  ElevatedButton(
                    onPressed: () => onPoints(d),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: Text('+$d', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onPoints(-1),
              icon: const Icon(Icons.remove, size: 16),
              label: const Text('Quitar punto'),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 20),
            _sectionLabel('FALTAS'),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Quitar falta',
                  onPressed: fouls > 0 ? () => onFoul(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$fouls',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ),
                IconButton.filled(
                  tooltip: 'Añadir falta',
                  onPressed: () => onFoul(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.5,
      ),
    );
