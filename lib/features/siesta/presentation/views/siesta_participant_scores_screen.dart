import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'widgets/add_daily_score_dialog.dart';

class SiestaParticipantScoresScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final allScoresAsync = ref.watch(siestaDailyScoresProvider(competitionId));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final competitionsAsync = ref.watch(siestaCompetitionsProvider);
    final compList = competitionsAsync.hasValue ? (competitionsAsync.value ?? []) : [];
    bool isFinalizada = false;
    try {
      final currentComp = compList.firstWhere((c) => c.id == competitionId);
      isFinalizada = currentComp.estado == 'finalizada';
    } catch (e) {}
    final isAdminOrCoach = (userRole == 'admin' || userRole == 'entrenador') && !isFinalizada;

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: $participantName'),
        actions: [
          if (isAdminOrCoach)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Eliminar participante',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar Participante'),
                    content: const Text('¿Estás seguro? Se borrará al jugador y TODAS sus puntuaciones de esta competición. Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref.read(siestaRepositoryProvider).removeParticipantByUser(competitionId, userId);
                    ref.invalidate(siestaParticipantsProvider(competitionId));
                    ref.invalidate(siestaDailyScoresProvider(competitionId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participante eliminado')));
                      context.pop(); // Go back
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: allScoresAsync.when(
        data: (allScores) {
          final userScores = allScores.where((s) => s.userId == userId).toList();
          
          if (userScores.isEmpty) {
            return const Center(child: Text('No hay puntuaciones registradas para este participante.'));
          }
          
          return ListView.builder(
            itemCount: userScores.length,
            itemBuilder: (context, index) {
              final score = userScores[index];
              final dateStr = "${score.fecha.day}/${score.fecha.month}/${score.fecha.year}";
              
              return ListTile(
                title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar puntuación'),
                              content: const Text('¿Estás seguro de eliminar estos puntos? Se restarán de la clasificación general.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await ref.read(siestaRepositoryProvider).deleteDailyScore(score.id);
                              ref.invalidate(siestaDailyScoresProvider(competitionId));
                              ref.invalidate(siestaParticipantsProvider(competitionId));
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          }
                        },
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
      floatingActionButton: isAdminOrCoach ? FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AddDailyScoreDialog(
              competitionId: competitionId,
              userId: userId,
              participantName: participantName,
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Sumar Puntos'),
      ) : null,
    );
  }
}
