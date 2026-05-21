import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class SiestaHomeScreen extends ConsumerWidget {
  const SiestaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionsAsync = ref.watch(siestaCompetitionsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Competiciones de Siesta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(siestaCompetitionsProvider),
          ),
        ],
      ),
      body: competitionsAsync.when(
        data: (competitions) {
          if (competitions.isEmpty) {
            return const Center(
              child: Text(
                'No hay competiciones de siesta activas.\n¡Crea una para empezar!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(siestaCompetitionsProvider);
              await Future.delayed(const Duration(milliseconds: 100)); // To show loading spinner briefly
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: competitions.length,
              itemBuilder: (context, index) {
                final comp = competitions[index];
                IconData gameIcon = Icons.sports_tennis; // default
                if (comp.juego == 'Billar') gameIcon = Icons.sports;
                if (comp.juego == 'Tiro a canasta') gameIcon = Icons.sports_basketball;
                if (comp.juego == 'Bolos') gameIcon = Icons.sports_baseball; // close enough
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(gameIcon, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(comp.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${comp.juego} • Formato: ${comp.formato.replaceAll('_', ' ')}\nEstado: ${comp.estado}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdminOrCoach) PopupMenuButton<String>(
                          onSelected: (value) async {
                            final repo = ref.read(siestaRepositoryProvider);
                            if (value == 'terminado') {
                              try {
                                await repo.updateCompetitionStatus(comp.id, 'finalizada');
                                ref.invalidate(siestaCompetitionsProvider);
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            } else if (value == 'eliminar') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Eliminar Competición'),
                                  content: const Text('¿Estás seguro? Se borrarán todos los participantes, partidos y puntos.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await repo.deleteCompetition(comp.id);
                                  ref.invalidate(siestaCompetitionsProvider);
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            if (comp.estado != 'finalizada') const PopupMenuItem<String>(
                              value: 'terminado',
                              child: Text('Marcar como terminada'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'eliminar',
                              child: Text('Eliminar competición', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      if (comp.formato == 'individual') {
                        context.push('/siesta/daily/${comp.id}');
                      } else if (comp.formato == 'tiros_libres_seguidos') {
                        context.push('/siesta/freethrows/${comp.id}');
                      } else {
                        context.push('/siesta/league/${comp.id}');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdminOrCoach
          ? FloatingActionButton.extended(
              onPressed: () {
                context.push('/siesta/create');
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva Competición'),
            )
          : null,
    );
  }
}
