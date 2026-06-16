import 'package:flutter/material.dart';
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
          return _Scoreboard(match: match, canManage: canManage, ref: ref, context: context);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  final LiveMatchModel match;
  final bool canManage;
  final WidgetRef ref;
  final BuildContext context;
  const _Scoreboard({
    required this.match,
    required this.canManage,
    required this.ref,
    required this.context,
  });

  Future<void> _set(Map<String, dynamic> data) async {
    try {
      await ref.read(matchesRepositoryProvider).update(match.id, data);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          ),
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
                  onFoul: () => _set({'fouls1': match.fouls1 + 1}),
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
                  onFoul: () => _set({'fouls2': match.fouls2 + 1}),
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
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Finalizar partido'),
                          content: const Text('¿Seguro que quieres dar el partido por finalizado?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Finalizar')),
                          ],
                        ),
                      );
                      if (ok == true) _set({'estado': 'finalizado'});
                    },
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Reanudar partido'),
                    onPressed: () => _set({'estado': 'en_juego'}),
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
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final int score;
  final int fouls;
  final bool editable;
  final void Function(int delta) onPoints;
  final VoidCallback onFoul;
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
          Text('Faltas: $fouls', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          if (editable) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final d in [1, 2, 3])
                  ElevatedButton(
                    onPressed: () => onPoints(d),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: Text('+$d', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Corregir (-1)',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onPoints(-1),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sports, size: 18),
                  label: const Text('Falta'),
                  onPressed: onFoul,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
