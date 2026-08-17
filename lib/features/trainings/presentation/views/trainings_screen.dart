import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trainings_providers.dart';
import '../../data/models/training_model.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import 'create_training_screen.dart';
import 'training_plans_screen.dart';
import 'training_folder_screen.dart';

class TrainingsScreen extends ConsumerWidget {
  const TrainingsScreen({super.key});

  String _fecha(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingsAsync = ref.watch(trainingsProvider);
    final role = ref.watch(currentUserProfileProvider).value?.role ?? 'visitante';
    final canManage = role == 'admin' || role == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamientos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Planificaciones (PDF)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TrainingPlansScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(trainingsProvider),
          ),
        ],
      ),
      body: trainingsAsync.when(
        data: (trainings) {
          // Agrupar entrenamientos por grupo (carpetas).
          final Map<String?, List<TrainingModel>> byGroup = {};
          for (final t in trainings) {
            byGroup.putIfAbsent(t.teamId, () => []).add(t);
          }
          final folders = byGroup.entries.map((e) {
            final name = e.value.first.team?.nombre ?? 'General';
            DateTime? latest;
            for (final t in e.value) {
              if (t.fecha != null &&
                  (latest == null || t.fecha!.isAfter(latest))) {
                latest = t.fecha;
              }
            }
            return (
              groupId: e.key,
              name: name,
              count: e.value.length,
              latest: latest,
            );
          }).toList()
            ..sort((a, b) {
              if (a.groupId == null) return 1; // General al final
              if (b.groupId == null) return -1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trainingsProvider);
              await ref.read(trainingsProvider.future);
            },
            child: folders.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No hay entrenamientos todavía.')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final f = folders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.shade100,
                            child:
                                const Icon(Icons.folder, color: Colors.amber),
                          ),
                          title: Text(f.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${f.count} entrenamiento${f.count == 1 ? '' : 's'}'
                            '${f.latest != null ? ' · último ${_fecha(f.latest)}' : ''}',
                          ),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrainingFolderScreen(
                                  groupId: f.groupId,
                                  groupName: f.name,
                                ),
                              ),
                            );
                          },
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
                    builder: (_) => const CreateTrainingScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuevo entrenamiento'),
            )
          : null,
    );
  }
}
