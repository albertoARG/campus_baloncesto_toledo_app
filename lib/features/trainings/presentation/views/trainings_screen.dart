import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trainings_providers.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import 'create_training_screen.dart';
import 'training_detail_screen.dart';

class TrainingsScreen extends ConsumerWidget {
  const TrainingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingsAsync = ref.watch(trainingsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String role = userProfileAsync.value?.role ?? 'visitante';
    final bool canManage = role == 'admin' || role == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamientos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(trainingsProvider),
          ),
        ],
      ),
      body: trainingsAsync.when(
        data: (trainings) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trainingsProvider);
              await ref.read(trainingsProvider.future);
            },
            child: trainings.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No hay entrenamientos programados.')),
                    ],
                  )
                : ListView.builder(
            itemCount: trainings.length,
            itemBuilder: (context, index) {
              final training = trainings[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    training.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (training.descripcion != null)
                        Text(
                          training.descripcion!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Grupo: ${training.team?.nombre ?? 'General'} | Coach: ${training.coach?.nombre ?? 'Sin asignar'}',
                      ),
                    ],
                  ),
                  onTap: () {
                    if (canManage) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrainingDetailScreen(training: training),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Solo el staff puede ver los detalles del entrenamiento')),
                      );
                    }
                  },
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Eliminar'),
                                content: const Text(
                                  '¿Eliminar este entrenamiento?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await ref
                                    .read(trainingsRepositoryProvider)
                                    .deleteTraining(training.id);
                                ref.invalidate(trainingsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          },
                        )
                      : null,
                ),
              );
            },
          ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTrainingScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
