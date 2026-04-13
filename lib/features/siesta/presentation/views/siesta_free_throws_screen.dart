import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'widgets/add_free_throw_dialog.dart';

class SiestaFreeThrowsScreen extends ConsumerStatefulWidget {
  final String competitionId;
  const SiestaFreeThrowsScreen({super.key, required this.competitionId});

  @override
  ConsumerState<SiestaFreeThrowsScreen> createState() => _SiestaFreeThrowsScreenState();
}

class _SiestaFreeThrowsScreenState extends ConsumerState<SiestaFreeThrowsScreen> {
  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(siestaDailyScoresProvider(widget.competitionId));
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
        title: const Text('Clasificación Tiros Libres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(siestaDailyScoresProvider(widget.competitionId));
            },
          )
        ],
      ),
      body: scoresAsync.when(
        data: (scores) {
          if (scores.isEmpty) {
            return const Center(child: Text('No hay intentos registrados aún.'));
          }
          return ListView.builder(
            itemCount: scores.length,
            itemBuilder: (context, index) {
              final score = scores[index];
              final user = score.user;
              final name = user != null ? '${user.nombre} ${user.apellidos}' : 'Desconocido';
              final dateStr = "${score.fecha.day}/${score.fecha.month}/${score.fecha.year}";
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text('${index + 1}'),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Fecha: $dateStr'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.puntos} tiros',
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
                              title: const Text('Eliminar intento'),
                              content: const Text('¿Estás seguro de eliminar este resultado?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await ref.read(siestaRepositoryProvider).deleteDailyScore(score.id);
                              ref.invalidate(siestaDailyScoresProvider(widget.competitionId));
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
            builder: (ctx) => AddFreeThrowDialog(competitionId: widget.competitionId),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir Intento'),
      ) : null,
    );
  }
}
