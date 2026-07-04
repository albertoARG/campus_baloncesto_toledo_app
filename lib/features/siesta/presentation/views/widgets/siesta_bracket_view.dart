import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';
import '../../../data/models/siesta_match_model.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import 'update_match_score_dialog.dart';

class SiestaBracketView extends ConsumerWidget {
  final String competitionId;
  const SiestaBracketView({super.key, required this.competitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(siestaMatchesProvider(competitionId));
    final participantsAsync = ref.watch(
      siestaParticipantsProvider(competitionId),
    );
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

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const Center(
            child: Text('No hay partidos programados para las eliminatorias.'),
          );
        }

        // Group matches by 'ronda'
        final Map<String, List<SiestaMatchModel>> roundsMap = {};
        for (var m in matches) {
          final ronda = m.ronda?.trim() ?? 'Sin Ronda';
          roundsMap.putIfAbsent(ronda, () => []).add(m);
        }

        // Round order: groups (fase de grupos) ALWAYS first, then elimination
        // rounds at the end, ordered octavos -> cuartos -> semifinal -> final.
        const roundOrder = [
          'dieciseisavos',
          'octavos',
          'cuartos',
          'semifinal',
          'semifinales',
          'tercer',
          'final',
        ];
        int elimIndex(String r) =>
            roundOrder.indexWhere((e) => r.toLowerCase().contains(e));
        final sortedRoundKeys = roundsMap.keys.toList()
          ..sort((a, b) {
            final idxA = elimIndex(a);
            final idxB = elimIndex(b);
            final aElim = idxA != -1;
            final bElim = idxB != -1;
            // Both elimination rounds -> order by stage.
            if (aElim && bElim) return idxA.compareTo(idxB);
            // Only one elimination -> groups first, eliminations last.
            if (aElim) return 1;
            if (bElim) return -1;
            // Both groups/other -> alphabetical.
            return a.toLowerCase().compareTo(b.toLowerCase());
          });

        // We will display a 2D pannable board for the bracket
        return InteractiveViewer(
          constrained: false, // allows the child to grow indefinitely and scroll in all directions
          boundaryMargin: const EdgeInsets.all(80),
          minScale: 0.3,
          maxScale: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedRoundKeys.map((rondaName) {
                final roundMatches = roundsMap[rondaName]!;
                return Container(
                  width: 280, // fixed width for match cards
                  margin: const EdgeInsets.only(right: 32),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rondaName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      ...roundMatches.map((m) {
                        return participantsAsync.when(
                          data: (participants) {
                            final p1 = participants.firstWhere(
                              (p) => p.id == m.participant1Id,
                              orElse: () => participants.first,
                            );
                            final p2 = participants.firstWhere(
                              (p) => p.id == m.participant2Id,
                              orElse: () => participants.first,
                            );
                            final p1Name = p1.displayName;
                            final p2Name = p2.displayName;
                            final isFinished = m.estado == 'finalizado';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: InkWell(
                                onTap: isAdminOrCoach
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) =>
                                              UpdateMatchScoreDialog(
                                                match: m,
                                                competitionId: competitionId,
                                              ),
                                        );
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p1Name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            isFinished ? '${m.score1}' : '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p2Name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            isFinished ? '${m.score2}' : '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          loading: () => const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Cargando...'),
                            ),
                          ),
                          error: (e, s) => const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Error'),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
