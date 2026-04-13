import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'widgets/add_participant_dialog.dart';
import 'widgets/add_match_dialog.dart';
import 'widgets/siesta_bracket_view.dart';

class SiestaLeagueScreen extends ConsumerStatefulWidget {
  final String competitionId;
  const SiestaLeagueScreen({super.key, required this.competitionId});

  @override
  ConsumerState<SiestaLeagueScreen> createState() => _SiestaLeagueScreenState();
}

class _SiestaLeagueScreenState extends ConsumerState<SiestaLeagueScreen> {
  int _selectedTabIndex = 0; // 0 for Standings, 1 for Bracket

  void _sortParticipants(List<dynamic> group, List<dynamic> matches) {
    group.sort((a, b) {
      int ptsA = a.puntosLiga ?? 0;
      int ptsB = b.puntosLiga ?? 0;
      if (ptsA != ptsB) return ptsB.compareTo(ptsA);

      // TIE BREAKER: find all participants tied with this exact points score
      final tiedPts = ptsA;
      final tiedGroup = group.where((p) => (p.puntosLiga ?? 0) == tiedPts).toList();
      
      if (tiedGroup.length == 2) {
        // 2-way tie: Head-to-head matchup
        int aWins = 0;
        int bWins = 0;
        int aDiff = 0;
        int bDiff = 0;
        
        for (final m in matches) {
          if (m.estado != 'finalizado') continue;
          bool isA1 = m.participant1Id == a.id && m.participant2Id == b.id;
          bool isA2 = m.participant2Id == a.id && m.participant1Id == b.id;
          
          if (isA1 || isA2) {
            int scoreA = isA1 ? (m.score1 as int) : (m.score2 as int);
            int scoreB = isA1 ? (m.score2 as int) : (m.score1 as int);
            
            if (scoreA > scoreB) aWins++;
            else if (scoreB > scoreA) bWins++;
            
            aDiff += (scoreA - scoreB);
            bDiff += (scoreB - scoreA);
          }
        }
        
        if (aWins != bWins) return bWins.compareTo(aWins);
        if (aDiff != bDiff) return bDiff.compareTo(aDiff);
        
      } else if (tiedGroup.length > 2) {
        // Multi-way tie: point differential in matches strictly between the tied teams
        final tiedIds = tiedGroup.map((p) => p.id).toSet();
        
        int aDiff = 0;
        int bDiff = 0;
        
        for (final m in matches) {
          if (m.estado != 'finalizado') continue;
          if (tiedIds.contains(m.participant1Id) && tiedIds.contains(m.participant2Id)) {
            // This match is between tied teams
            if (m.participant1Id == a.id) {
              aDiff += (m.score1 as int) - (m.score2 as int);
            } else if (m.participant2Id == a.id) {
              aDiff += (m.score2 as int) - (m.score1 as int);
            }
            
            if (m.participant1Id == b.id) {
              bDiff += (m.score1 as int) - (m.score2 as int);
            } else if (m.participant2Id == b.id) {
              bDiff += (m.score2 as int) - (m.score1 as int);
            }
          }
        }
        
        if (aDiff != bDiff) return bDiff.compareTo(aDiff);
      }
      
      // Ultimate fallback: total overall wins
      int winsA = a.partidosGanados ?? 0;
      int winsB = b.partidosGanados ?? 0;
      if (winsA != winsB) return winsB.compareTo(winsA);
      
      return 0; // completely tied
    });
  }

  @override
  Widget build(BuildContext context) {
    final participantsAsync = ref.watch(siestaParticipantsProvider(widget.competitionId));
    final matchesAsync = ref.watch(siestaMatchesProvider(widget.competitionId));
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
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Clasificación / Eliminatorias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(siestaParticipantsProvider(widget.competitionId));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Clasificación'), icon: Icon(Icons.list)),
                ButtonSegment(value: 1, label: Text('Eliminatorias / Cuadro'), icon: Icon(Icons.account_tree)),
              ],
              selected: {_selectedTabIndex},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedTabIndex = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? participantsAsync.when(
                    data: (participants) {
                      if (participants.isEmpty) {
                        return const Center(child: Text('Aún no hay participantes en esta liga.'));
                      }

                      // Group participants
                      final Map<String, List<dynamic>> groups = {};
                      for (var p in participants) {
                        final g = p.grupo?.trim() ?? '';
                        final groupName = g.isEmpty ? 'General' : 'Grupo $g';
                        groups.putIfAbsent(groupName, () => []).add(p);
                      }

                      // Sort groups alphabetically
                      final sortedKeys = groups.keys.toList()..sort();

                      return ListView.builder(
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, index) {
                          final groupName = sortedKeys[index];
                          final groupParticipants = List.from(groups[groupName]!);
                          
                          // Advanced FIBA tiebreaker sorting logic utilizing match data
                          final matches = matchesAsync.hasValue ? (matchesAsync.value ?? []) : [];
                          _sortParticipants(groupParticipants, matches);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              ...groupParticipants.asMap().entries.map((entry) {
                                final pos = entry.key + 1;
                                final participant = entry.value;
                                final user = participant.user;
                                final name = user != null ? '${user.nombre} ${user.apellidos}' : 'Desconocido';
                                
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Text('$pos'),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('J: ${participant.partidosJugados} | G: ${participant.partidosGanados} | P: ${participant.partidosPerdidos}'),
                                  trailing: Text(
                                    '${participant.puntosLiga} pts',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  onTap: () {
                                    context.push('/siesta/participant/${widget.competitionId}/${participant.id}');
                                  },
                                );
                              }),
                              const Divider(),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  )
                : SiestaBracketView(competitionId: widget.competitionId),
          ),
        ],
      ),
      floatingActionButton: isAdminOrCoach ? FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctxBottomSheet) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Inscribir Participante'),
                    onTap: () {
                      Navigator.pop(ctxBottomSheet);
                      showDialog(
                        context: context,
                        builder: (ctxDialog) => AddParticipantDialog(competitionId: widget.competitionId),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sports),
                    title: const Text('Registrar Partido'),
                    onTap: () {
                      Navigator.pop(ctxBottomSheet);
                      showDialog(
                        context: context,
                        builder: (ctxDialog) => AddMatchDialog(competitionId: widget.competitionId),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ) : null,
    );
  }
}
