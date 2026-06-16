import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/matches_providers.dart';
import '../../data/models/live_match_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final role = ref.watch(currentUserProfileProvider).value?.role ?? 'visitante';
    final canManage = role == 'admin' || role == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Partidos en Directo'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.groups),
              tooltip: 'Equipos de partidos',
              onPressed: () => context.push('/match-teams'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(matchesStreamProvider),
          ),
        ],
      ),
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay partidos. Crea uno para empezar a llevar el marcador en directo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: matches.length,
            itemBuilder: (context, index) =>
                _MatchCard(match: matches[index], canManage: canManage),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo partido'),
            )
          : null,
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    String? team1Id, team2Id;
    String? team1Name, team2Name;

    showDialog(
      context: context,
      builder: (ctx) {
        final teamsAsync = ref.watch(matchTeamsProvider);
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Nuevo partido'),
            content: teamsAsync.when(
              data: (teams) {
                if (teams.length < 2) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          'Necesitas al menos dos equipos de partidos. Créalos en "Equipos de partidos".'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.groups),
                        label: const Text('Gestionar equipos'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/match-teams');
                        },
                      ),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: team1Id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Equipo local'),
                      items: teams
                          .map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.nombre, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        team1Id = v;
                        team1Name = teams.firstWhere((t) => t.id == v).nombre;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: team2Id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Equipo visitante'),
                      items: teams
                          .map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.nombre, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        team2Id = v;
                        team2Name = teams.firstWhere((t) => t.id == v).nombre;
                      }),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => Text('Error: $e'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (team1Id == null || team2Id == null) return;
                  if (team1Id == team2Id) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Elige dos equipos distintos.')),
                    );
                    return;
                  }
                  try {
                    final newId = await ref.read(matchesRepositoryProvider).createMatch(
                          team1Id: team1Id!,
                          team1Name: team1Name!,
                          team2Id: team2Id!,
                          team2Name: team2Name!,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) context.push('/matches/$newId');
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al crear el partido: $e')),
                      );
                    }
                  }
                },
                child: const Text('Empezar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchCard extends ConsumerWidget {
  final LiveMatchModel match;
  final bool canManage;
  const _MatchCard({required this.match, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final live = !match.finalizado;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${match.team1Name}  vs  ${match.team2Name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: live ? Colors.red : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                live ? 'EN JUEGO' : 'FINAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: live ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${match.score1} - ${match.score2}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        trailing: canManage && match.finalizado
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Eliminar partido'),
                      content: const Text('¿Borrar este partido finalizado?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(matchesRepositoryProvider).deleteMatch(match.id);
                  }
                },
              )
            : const Icon(Icons.chevron_right),
        onTap: () => context.push('/matches/${match.id}'),
      ),
    );
  }
}
