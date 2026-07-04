import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/competitions_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class UserStationScoresScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  const UserStationScoresScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<UserStationScoresScreen> createState() =>
      _UserStationScoresScreenState();
}

class _UserStationScoresScreenState
    extends ConsumerState<UserStationScoresScreen> {
  String? _selectedDayFilter;
  String? _selectedStationFilter;

  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(userScoresProvider(widget.userId));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Puntos de ${widget.userName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userScoresProvider(widget.userId));
              ref.invalidate(globalStandingsProvider);
            },
          ),
        ],
      ),
      body: scoresAsync.when(
        data: (scores) {
          // Filter by published if not admin/coach
          final visibleScores = isAdminOrCoach
              ? scores
              : scores
                  .where(
                      (s) => s['station_days']?['is_published'] == true)
                  .toList();

          if (visibleScores.isEmpty) {
            return const Center(
              child: Text(
                'Este jugador aún no tiene puntuaciones registradas.',
              ),
            );
          }

          // ── Extract unique days and stations for filters ──
          final Map<String, String> dayOptions = {};
          final Map<String, String> stationOptions = {};

          for (final s in visibleScores) {
            final dayId = s['station_day_id'] as String?;
            final dayName = s['station_days']?['nombre'] as String? ?? 'Día';
            if (dayId != null) dayOptions[dayId] = dayName;

            final stationId = s['station_id'] as String?;
            final stationName =
                s['stations']?['nombre'] as String? ?? 'Estación';
            if (stationId != null) stationOptions[stationId] = stationName;
          }

          // Sort the options alphabetically by name
          final sortedDays = dayOptions.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));
          final sortedStations = stationOptions.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));

          // ── Apply filters ──
          var filteredScores = visibleScores;
          if (_selectedDayFilter != null) {
            filteredScores = filteredScores
                .where((s) => s['station_day_id'] == _selectedDayFilter)
                .toList();
          }
          if (_selectedStationFilter != null) {
            filteredScores = filteredScores
                .where((s) => s['station_id'] == _selectedStationFilter)
                .toList();
          }

          // ── Summary stats ──
          int totalPoints = 0;
          for (final s in filteredScores) {
            totalPoints += (s['score'] as int? ?? 0);
          }

          return Column(
            children: [
              // ── Filter bar ──
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Day filter
                    Row(
                      children: [
                        const SizedBox(
                          width: 70,
                          child: Text('Día:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedDayFilter,
                            hint: const Text('Todos los días'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los días'),
                              ),
                              ...sortedDays.map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedDayFilter = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    // Station filter
                    Row(
                      children: [
                        const SizedBox(
                          width: 70,
                          child: Text('Estación:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedStationFilter,
                            hint: const Text('Todas las estaciones'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todas las estaciones'),
                              ),
                              ...sortedStations.map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedStationFilter = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Summary bar ──
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryChip(
                      icon: Icons.format_list_numbered,
                      label: 'Registros',
                      value: '${filteredScores.length}',
                    ),
                    _SummaryChip(
                      icon: Icons.stars,
                      label: 'Total',
                      value: '$totalPoints pts',
                    ),
                  ],
                ),
              ),

              // ── Scores list ──
              Expanded(
                child: filteredScores.isEmpty
                    ? const Center(
                        child: Text(
                            'No hay puntuaciones con estos filtros.'))
                    : ListView.builder(
                        itemCount: filteredScores.length,
                        itemBuilder: (context, index) {
                          final score = filteredScores[index];
                          final stationName =
                              score['stations']?['nombre'] ?? 'Prueba';
                          final dayName =
                              score['station_days']?['nombre'] ?? 'Día';
                          final points = score['score'] ?? 0;
                          final scoreId = score['id'];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: const Icon(
                                    Icons.check_circle_outline),
                              ),
                              title: Text(
                                stationName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                  if (isAdminOrCoach) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 20),
                                      onPressed: () => _showEditDialog(
                                        context,
                                        ref,
                                        scoreId,
                                        points,
                                        widget.userId,
                                        score['station_day_id'] as String?,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _confirmDelete(
                                          context,
                                          ref,
                                          scoreId,
                                          widget.userId),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String scoreId,
    int currentScore,
    String userId,
    String? currentDayId,
  ) async {
    final controller = TextEditingController(text: currentScore.toString());
    final days = await ref.read(stationDaysProvider.future);
    String? selectedDayId = currentDayId;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Puntuación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Nueva Puntuación'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Día de Competición'),
                value: selectedDayId,
                items: days
                    .map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.nombre),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedDayId = val),
              ),
            ],
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
                  await ref.read(competitionsRepositoryProvider).updateScore(
                        scoreId,
                        newScore,
                        newDayId: selectedDayId != currentDayId
                            ? selectedDayId
                            : null,
                      );
                  ref.invalidate(userScoresProvider(userId));
                  ref.invalidate(globalStandingsProvider);
                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
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
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
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

// ── Summary chip widget ──

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
