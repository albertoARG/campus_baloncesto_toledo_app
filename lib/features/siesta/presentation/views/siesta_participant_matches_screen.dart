import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'widgets/update_match_score_dialog.dart';

class SiestaParticipantMatchesScreen extends ConsumerStatefulWidget {
  final String competitionId;
  final String participantId;
  const SiestaParticipantMatchesScreen({
    super.key, 
    required this.competitionId, 
    required this.participantId
  });

  @override
  ConsumerState<SiestaParticipantMatchesScreen> createState() => _SiestaParticipantMatchesScreenState();
}

class _SiestaParticipantMatchesScreenState extends ConsumerState<SiestaParticipantMatchesScreen> {
  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(siestaMatchesProvider(widget.competitionId));
    final participantsAsync = ref.watch(siestaParticipantsProvider(widget.competitionId));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final competitionsAsync = ref.watch(siestaCompetitionsProvider);
    final compList = competitionsAsync.hasValue ? (competitionsAsync.value ?? []) : [];
    bool isFinalizada = false;
    try {
      final currentComp = compList.firstWhere((c) => c.id == widget.competitionId);
      isFinalizada = currentComp.estado == 'finalizada';
    } catch (e) {}
    final isAdminOrCoach = (userRole == 'admin' || userRole == 'entrenador') && !isFinalizada;

    // Find the participant's name
    String participantName = "Cargando...";
    if (participantsAsync.hasValue) {
      try {
        final p = participantsAsync.value!.firstWhere((p) => p.id == widget.participantId);
        participantName = p.user != null ? '${p.user!.nombre} ${p.user!.apellidos}' : 'Jugador';
      } catch (e) {
        participantName = 'Participante desconocido';
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Partidos de $participantName'),
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
                    content: const Text('¿Estás seguro? Se borrará al jugador y TODOS sus partidos de esta competición. Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref.read(siestaRepositoryProvider).removeParticipant(widget.participantId);
                    ref.invalidate(siestaParticipantsProvider(widget.competitionId));
                    ref.invalidate(siestaMatchesProvider(widget.competitionId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participante eliminado')));
                      context.pop();
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
      body: matchesAsync.when(
        data: (allMatches) {
          final myMatches = allMatches.where((m) => 
            m.participant1Id == widget.participantId || m.participant2Id == widget.participantId
          ).toList();

          if (myMatches.isEmpty) {
            return const Center(child: Text('No hay partidos programados para este jugador.'));
          }

          return ListView.builder(
            itemCount: myMatches.length,
            itemBuilder: (context, index) {
              final match = myMatches[index];
              return participantsAsync.when(
                data: (participants) {
                  final p1 = participants.firstWhere((p) => p.id == match.participant1Id, orElse: () => participants.first);
                  final p2 = participants.firstWhere((p) => p.id == match.participant2Id, orElse: () => participants.first);
                  
                  final p1Name = p1.user != null ? '${p1.user!.nombre} ${p1.user!.apellidos}' : 'P1';
                  final p2Name = p2.user != null ? '${p2.user!.nombre} ${p2.user!.apellidos}' : 'P2';
                  
                  final isFinished = match.estado == 'finalizado';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () {
                        if (isAdminOrCoach) {
                          showDialog(
                            context: context,
                            builder: (ctx) => UpdateMatchScoreDialog(match: match, competitionId: widget.competitionId),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (match.ronda != null && match.ronda!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(match.ronda!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(p1Name, textAlign: TextAlign.right, style: TextStyle(fontWeight: widget.participantId == p1.id ? FontWeight.bold : FontWeight.normal))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isFinished ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isFinished ? '${match.score1} - ${match.score2}' : 'VS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: isFinished ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black54
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(child: Text(p2Name, textAlign: TextAlign.left, style: TextStyle(fontWeight: widget.participantId == p2.id ? FontWeight.bold : FontWeight.normal))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const ListTile(title: Text('Cargando oponentes...')),
                error: (e,s) => ListTile(title: Text('Error $e')),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
