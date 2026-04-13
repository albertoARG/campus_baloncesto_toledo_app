import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'widgets/add_participant_dialog.dart';

class SiestaDailyLadderScreen extends ConsumerStatefulWidget {
  final String competitionId;
  const SiestaDailyLadderScreen({super.key, required this.competitionId});

  @override
  ConsumerState<SiestaDailyLadderScreen> createState() => _SiestaDailyLadderScreenState();
}

class _SiestaDailyLadderScreenState extends ConsumerState<SiestaDailyLadderScreen> {
  @override
  Widget build(BuildContext context) {
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
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Clasificación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(siestaParticipantsProvider(widget.competitionId));
            },
          )
        ],
      ),
      body: participantsAsync.when(
        data: (participants) {
          if (participants.isEmpty) {
            return const Center(child: Text('No hay participantes registrados aún.'));
          }
          // Sort by points descending just in case
          final sortedParticipants = List.from(participants)..sort((a, b) => ((b as dynamic).puntosLiga ?? 0).compareTo((a as dynamic).puntosLiga ?? 0));
          
          return ListView.builder(
            itemCount: sortedParticipants.length,
            itemBuilder: (context, index) {
              final participant = sortedParticipants[index];
              final user = participant.user;
              final name = user != null ? '${user.nombre} ${user.apellidos}' : 'Desconocido';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text('${index + 1}'),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Toca para ver historial y sumar puntos'),
                trailing: Text(
                  '${participant.puntosLiga} pts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () {
                  context.push('/siesta/participant_scores/${widget.competitionId}/${participant.userId}', extra: name);
                },
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
            builder: (ctx) => AddParticipantDialog(competitionId: widget.competitionId),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Añadir Participante'),
      ) : null,
    );
  }
}
