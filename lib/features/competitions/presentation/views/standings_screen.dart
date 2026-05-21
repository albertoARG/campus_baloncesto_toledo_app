import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/user_model.dart';
import '../providers/competitions_providers.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/services/export_service.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final selectedDayId = ref.watch(selectedDayIdProvider);
    final standingsAsync = ref.watch(globalStandingsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final daysAsync = ref.watch(stationDaysProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clasificación'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isAdminOrCoach) ...[
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Exportar Clasificación a Excel',
              onPressed: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Generando Excel, esto puede tardar unos segundos...',
                      ),
                    ),
                  );
                  final msg = await ref
                      .read(exportServiceProvider)
                      .exportStandingsToExcel();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al exportar: \$e')),
                    );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/competitions/manage'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(globalStandingsProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Text(
                        'Grupo: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: groupsAsync.when(
                        data: (groups) {
                          return DropdownButton<String?>(
                            isExpanded: true,
                            value: selectedGroupId,
                            hint: const Text('Todos los jugadores'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los jugadores'),
                              ),
                              ...groups.map(
                                (g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.nombre),
                                ),
                              ),
                            ],
                            onChanged: (newVal) {
                              ref
                                  .read(selectedGroupIdProvider.notifier)
                                  .setGroup(newVal);
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => const Text('Error loading groups'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Text(
                        'Día: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: daysAsync.when(
                        data: (days) {
                          return DropdownButton<String?>(
                            isExpanded: true,
                            value: selectedDayId,
                            hint: const Text('Todos los días'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los días'),
                              ),
                              ...days.map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.nombre),
                                ),
                              ),
                            ],
                            onChanged: (newVal) {
                              ref
                                  .read(selectedDayIdProvider.notifier)
                                  .setDay(newVal);
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => const Text('Error loading days'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: standingsAsync.when(
        data: (rankings) {
          if (rankings.isEmpty) {
            return const Center(
              child: Text('Aún no hay puntuaciones registradas.'),
            );
          }

          return ListView.builder(
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final ranking = rankings[index];
              final UserModel player = ranking['player'];
              final int totalScore = ranking['totalScore'];

              // Medal colors for top 3
              Color? iconColor;
              if (index == 0)
                iconColor = Colors.amber; // Gold
              else if (index == 1)
                iconColor = Colors.grey[400]; // Silver
              else if (index == 2)
                iconColor = Colors.brown[300]; // Bronze

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: index < 3 ? 4 : 1,
                child: InkWell(
                  onTap: isAdminOrCoach ? () {
                    context.push(
                      '/competitions/user/${player.id}',
                      extra: '${player.nombre} ${player.apellidos}',
                    );
                  } : null,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          iconColor ??
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: index < 3
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      '${player.nombre} ${player.apellidos}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.posicion ?? 'Jugador'),
                        if (isAdminOrCoach) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Toca para ver historial',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Text(
                      '$totalScore pts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error cargando clasificación: ${error.toString()}'),
        ),
      ),
    );
  }
}
