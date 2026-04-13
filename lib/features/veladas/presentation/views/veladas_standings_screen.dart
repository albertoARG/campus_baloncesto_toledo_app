import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/veladas_providers.dart';

class VeladasStandingsScreen extends ConsumerWidget {
  const VeladasStandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(veladasStandingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clasificación de Veladas'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(veladasStandingsProvider),
          ),
        ],
      ),
      body: standingsAsync.when(
        data: (rankings) {
          if (rankings.isEmpty) {
             return const Center(child: Text('Aún no hay puntuaciones de veladas.'));
          }

          return ListView.builder(
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final rank = rankings[index];
              final player = rank['player'];
              final score = rank['veladas_won'] as int;
              
              Widget medalOrRank;
              if (index == 0 && score > 0) {
                medalOrRank = const Icon(Icons.emoji_events, color: Colors.amber, size: 30);
              } else if (index == 1 && score > 0) {
                medalOrRank = const Icon(Icons.emoji_events, color: Colors.grey, size: 30);
              } else if (index == 2 && score > 0) {
                medalOrRank = const Icon(Icons.emoji_events, color: Colors.brown, size: 30);
              } else {
                medalOrRank = Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                );
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: SizedBox(
                    width: 40,
                    child: Center(child: medalOrRank),
                  ),
                  title: Text(
                    '${player.nombre} ${player.apellidos}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${player.posicion ?? 'Jugador'} - Edad: ${player.edad ?? '?'}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$score pts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
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
}
