import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'widgets/add_daily_score_dialog.dart';

class SiestaParticipantScoresScreen extends ConsumerStatefulWidget {
  final String competitionId;
  final String userId;
  final String participantName;

  const SiestaParticipantScoresScreen({
    super.key,
    required this.competitionId,
    required this.userId,
    required this.participantName,
  });

  @override
  ConsumerState<SiestaParticipantScoresScreen> createState() =>
      _SiestaParticipantScoresScreenState();
}

class _SiestaParticipantScoresScreenState
    extends ConsumerState<SiestaParticipantScoresScreen> {
  // Puntuaciones ocultas mientras corre la ventana de "deshacer".
  final Set<String> _pendingDeleteIds = {};

  Future<void> _deleteScore(dynamic score) async {
    // Se oculta y se dan 5 s para deshacer antes de borrar de verdad.
    setState(() => _pendingDeleteIds.add(score.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('Puntuación eliminada (${score.puntos} pts)'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'DESHACER', onPressed: () {}),
      ),
    );

    final reason = await controller.closed;
    if (!mounted) return;

    if (reason == SnackBarClosedReason.action) {
      setState(() => _pendingDeleteIds.remove(score.id));
      return;
    }

    try {
      await ref.read(siestaRepositoryProvider).deleteDailyScore(score.id);
      ref.invalidate(siestaDailyScoresProvider(widget.competitionId));
      ref.invalidate(siestaParticipantsProvider(widget.competitionId));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(score.id));
    }
  }

  Future<void> _removeParticipant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Participante'),
        content: const Text(
            '¿Estás seguro? Se borrará al jugador y TODAS sus puntuaciones de esta competición. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(siestaRepositoryProvider)
          .removeParticipantByUser(widget.competitionId, widget.userId);
      ref.invalidate(siestaParticipantsProvider(widget.competitionId));
      ref.invalidate(siestaDailyScoresProvider(widget.competitionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Participante eliminado')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allScoresAsync =
        ref.watch(siestaDailyScoresProvider(widget.competitionId));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final competitionsAsync = ref.watch(siestaCompetitionsProvider);
    final compList =
        competitionsAsync.hasValue ? (competitionsAsync.value ?? []) : [];
    bool isFinalizada = false;
    try {
      final currentComp =
          compList.firstWhere((c) => c.id == widget.competitionId);
      isFinalizada = currentComp.estado == 'finalizada';
    } catch (e) {}
    final isAdminOrCoach =
        (userRole == 'admin' || userRole == 'entrenador') && !isFinalizada;

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: ${widget.participantName}'),
        actions: [
          if (isAdminOrCoach)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Eliminar participante',
              onPressed: _removeParticipant,
            ),
        ],
      ),
      body: allScoresAsync.when(
        data: (allScores) {
          final userScores = allScores
              .where((s) =>
                  s.userId == widget.userId &&
                  !_pendingDeleteIds.contains(s.id))
              .toList();

          if (userScores.isEmpty) {
            return const Center(
                child: Text(
                    'No hay puntuaciones registradas para este participante.'));
          }

          return ListView.builder(
            itemCount: userScores.length,
            itemBuilder: (context, index) {
              final score = userScores[index];
              final dateStr =
                  "${score.fecha.day}/${score.fecha.month}/${score.fecha.year}";

              return ListTile(
                title: Text(dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${score.puntos} pts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (isAdminOrCoach) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteScore(score),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdminOrCoach
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddDailyScoreDialog(
                    competitionId: widget.competitionId,
                    userId: widget.userId,
                    participantName: widget.participantName,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Sumar Puntos'),
            )
          : null,
    );
  }
}
