import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_providers.dart';
import 'edit_stat_screen.dart';

class PlayerStatsHistoryScreen extends ConsumerWidget {
  final String userId;
  final String userName;

  const PlayerStatsHistoryScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // actually currentUserStatsProvider uses currentUserProfileProvider.
    // I should create a new provider or just fetch the user stats directly or create a family provider.
    // I'll create a new provider `playerStatsProvider(userId)` in stats_providers.dart or just use FutureBuilder here.
    // Let's use a FutureBuilder with the repository to keep it simple, or add a family provider.
    
    // For now, let's just fetch directly using FutureBuilder and the repository.
    final repository = ref.watch(statsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Estadísticas: $userName')),
      body: FutureBuilder(
        future: repository.getUserStats(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? [];

          if (stats.isEmpty) {
            return const Center(child: Text('Aún no tiene estadísticas registradas'));
          }

          int totalPts = 0;
          int totalReb = 0;
          int totalAst = 0;
          int totalMvp = 0;

          for (var s in stats) {
            totalPts += s.points;
            totalReb += s.rebounds;
            totalAst += s.assists;
            if (s.isMvp) totalMvp++;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Totales del Campus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBox('PTS', totalPts.toString()),
                  _StatBox('REB', totalReb.toString()),
                  _StatBox('AST', totalAst.toString()),
                  _StatBox('MVPs', totalMvp.toString(), color: Colors.amber),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Historial de Partidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...stats.map((s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(s.matchName ?? 'Partido sin nombre'),
                      subtitle: Text('Pts: ${s.points} | Reb: ${s.rebounds} | Ast: ${s.assists} | Rob: ${s.steals} | Tap: ${s.blocks}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.isMvp) const Icon(Icons.star, color: Colors.amber),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditStatScreen(stat: s, userName: userName),
                                ),
                              ).then((_) {
                                // refresh stats
                                // ref.invalidate(allStatsProvider);
                                // Hacky way to force rebuild of FutureBuilder is to use setState, but this is a ConsumerWidget.
                                // Instead of a stateful widget, let's just invalidate allStatsProvider and force a redraw if we used a provider.
                                // I will just pop and push replacement or invalidate.
                                ref.invalidate(allStatsProvider);
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Eliminar Estadísticas'),
                                  content: const Text('¿Estás seguro de que quieres eliminar estas estadísticas?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await repository.deleteStat(s.id);
                                ref.invalidate(allStatsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado correctamente')));
                                  // Refresh the page
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation1, animation2) => PlayerStatsHistoryScreen(userId: userId, userName: userName),
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ))
            ],
          );
        },
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatBox(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? Theme.of(context).colorScheme.primary),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color ?? Theme.of(context).colorScheme.primary)),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
