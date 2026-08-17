import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trainings_providers.dart';
import '../../data/models/training_plan_data.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import 'create_training_screen.dart';
import 'training_detail_screen.dart';

/// Muestra los entrenamientos de un grupo (una "carpeta"), ordenados por día.
class TrainingFolderScreen extends ConsumerWidget {
  final String? groupId; // null = General (sin grupo)
  final String groupName;

  const TrainingFolderScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  String _fecha(DateTime? d) => d == null
      ? 'Sin fecha'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingsAsync = ref.watch(trainingsProvider);
    final role = ref.watch(currentUserProfileProvider).value?.role ?? 'visitante';
    final canManage = role == 'admin' || role == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
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
        data: (all) {
          final trainings =
              all.where((t) => t.teamId == groupId).toList();
          if (trainings.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Aún no hay entrenamientos en esta carpeta.\nPulsa «+» para añadir uno.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trainingsProvider);
              await ref.read(trainingsProvider.future);
            },
            child: ListView.builder(
              itemCount: trainings.length,
              itemBuilder: (context, index) {
                final training = trainings[index];
                final plan = TrainingPlanData.tryParse(training.descripcion);
                final resumen = plan != null
                    ? (plan.objetivos.trim().isNotEmpty
                        ? plan.objetivos.trim()
                        : 'Ficha de sesión${plan.ejercicios.isNotEmpty ? ' · ${plan.ejercicios.length} ejercicios' : ''}')
                    : (training.descripcion ?? '');
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.event_note),
                    ),
                    title: Text(training.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (resumen.isNotEmpty)
                          Text(resumen,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          '${_fecha(training.fecha)} · Coach: ${training.coach?.nombre ?? 'Sin asignar'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (canManage) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TrainingDetailScreen(training: training),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Solo el staff puede ver los detalles del entrenamiento')),
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
                                      '¿Eliminar este entrenamiento?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancelar')),
                                    TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Eliminar',
                                            style:
                                                TextStyle(color: Colors.red))),
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
                                        SnackBar(content: Text('Error: $e')));
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
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateTrainingScreen(initialTeamId: groupId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Añadir'),
            )
          : null,
    );
  }
}
