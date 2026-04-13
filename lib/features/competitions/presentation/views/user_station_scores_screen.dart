import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/competitions_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class UserStationScoresScreen extends ConsumerWidget {
  final String userId;
  final String userName;
  const UserStationScoresScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We create a dedicated provider for this user's scores to handle invalidation easily
    final scoresAsync = ref.watch(userScoresProvider(userId));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Puntos de $userName'),
      ),
      body: scoresAsync.when(
        data: (scores) {
          if (scores.isEmpty) {
            return const Center(
              child: Text(
                'Este jugador aún no tiene puntuaciones registradas.',
              ),
            );
          }

          return ListView.builder(
            itemCount: scores.length,
            itemBuilder: (context, index) {
              final score = scores[index];
              final stationName = score['stations']?['nombre'] ?? 'Prueba';
              final dayName = score['station_days']?['nombre'] ?? 'Día';
              final points = score['score'] ?? 0;
              final scoreId = score['id'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: const Icon(Icons.check_circle_outline),
                  ),
                  title: Text(
                    stationName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(dayName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$points pts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (isAdminOrCoach) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditDialog(
                            context,
                            ref,
                            scoreId,
                            points,
                            userId,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              _confirmDelete(context, ref, scoreId, userId),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String scoreId,
    int currentScore,
    String userId,
  ) {
    final controller = TextEditingController(text: currentScore.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Puntuación'),
        content: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nueva Puntuación'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newScore = int.tryParse(controller.text);
              if (newScore != null) {
                await ref
                    .read(competitionsRepositoryProvider)
                    .updateScore(scoreId, newScore);
                ref.invalidate(userScoresProvider(userId));
                ref.invalidate(globalStandingsProvider);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String scoreId,
    String userId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Puntos'),
        content: const Text(
          '¿Estás seguro de que quieres borrar esta puntuación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(competitionsRepositoryProvider).deleteScore(scoreId);
      ref.invalidate(userScoresProvider(userId));
      ref.invalidate(globalStandingsProvider);
    }
  }
}
