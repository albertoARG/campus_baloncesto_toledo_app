import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/velada_model.dart';
import '../providers/veladas_providers.dart';
import '../../data/models/velada_group_model.dart';
import '../../data/models/velada_member_model.dart';
import '../../../admin/presentation/providers/admin_providers.dart';

class VeladaDetailScreen extends ConsumerWidget {
  final VeladaModel velada;

  const VeladaDetailScreen({super.key, required this.velada});

  void _showGenerateGroupsDialog(BuildContext context, WidgetRef ref) {
    final numController = TextEditingController(text: '4');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Grupos Equilibrados'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esta acción borrará los grupos actuales de esta velada y creará nuevos repartiendo a los jugadores por edad.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Número de grupos'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              int? n = int.tryParse(numController.text.trim());
              if (n == null || n < 1) return;

              try {
                // Show a loading indicator ideally, but passing directly for simplicity
                Navigator.pop(context); // close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando grupos...')),
                );

                await ref
                    .read(veladasRepositoryProvider)
                    .generateBalancedGroups(velada.id, n);

                ref.invalidate(veladaGroupsProvider(velada.id));
                // We don't invalidate all members here because the parent group ids changed anyway
                // so the FutureProvider family calls will be fresh.

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Grupos generados con éxito!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(veladaGroupsProvider(velada.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(velada.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Eliminar Velada'),
                  content: const Text(
                    '¿Seguro que quieres borrar toda la velada y sus grupos?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(veladasRepositoryProvider)
                    .deleteVelada(velada.id);
                ref.invalidate(allVeladasProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Velada eliminada')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No hay grupos creados.\nPulsa el botón de abajo para generar grupos equilibrados automáticamente.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            padding: const EdgeInsets.only(bottom: 80), // Fab spacing
            itemBuilder: (context, index) {
              final group = groups[index];
              return _GroupCard(veladaId: velada.id, group: group);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateGroupsDialog(context, ref),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generar Grupos'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final String veladaId;
  final VeladaGroupModel group;

  const _GroupCard({required this.veladaId, required this.group});

  void _showAddMemberDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final usersAsync = ref.watch(allUsersProvider);
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Añadir Jugador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: usersAsync.when(
                    data: (users) {
                      final eligibleUsers = users.where((u) => u.role == 'jugador' || u.role == 'visitante').toList();
                      return ListView.builder(
                        itemCount: eligibleUsers.length,
                        itemBuilder: (context, index) {
                          final user = eligibleUsers[index];
                          return ListTile(
                            title: Text('${user.nombre} ${user.apellidos}'),
                            subtitle: Text('Edad: ${user.edad ?? "?"}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () async {
                                try {
                                  await ref.read(veladasRepositoryProvider).addMemberToGroup(group.id, user.id);
                                  ref.invalidate(veladaGroupMembersProvider(group.id));
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.nombre} añadido')));
                                  }
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(veladaGroupMembersProvider(group.id));

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: group.isWinner ? Colors.amber : Colors.transparent,
          width: group.isWinner ? 3 : 0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: group.isWinner ? 8 : 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: group.isWinner
                  ? Colors.amber.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.nombre + (group.isWinner ? ' 🏆 GANADOR' : ''),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: group.isWinner
                        ? Colors.amber.shade900
                        : Colors.black87,
                  ),
                ),
                if (!group.isWinner)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                    ),
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text(
                      'Marcar Ganador',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      await ref
                          .read(veladasRepositoryProvider)
                          .markGroupAsWinner(veladaId, group.id);
                      ref.invalidate(veladaGroupsProvider(veladaId));
                    },
                  ),
              ],
            ),
          ),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sin jugadores'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddMemberDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Jugador Manulamente'),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    itemBuilder: (context, i) {
                      final m = members[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: m.isCaptain
                              ? Colors.red.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            m.isCaptain ? Icons.star : Icons.person,
                            size: 16,
                            color: m.isCaptain ? Colors.red : Colors.blue,
                          ),
                        ),
                        title: Text(
                          '${m.user?.nombre} ${m.user?.apellidos}',
                          style: TextStyle(
                            fontWeight: m.isCaptain
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'Edad: ${m.user?.edad ?? '?'} - Pos: ${m.user?.posicion ?? '?'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (m.isCaptain)
                              const Chip(
                                label: Text(
                                  'Capitán',
                                  style: TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                await ref.read(veladasRepositoryProvider).removeMemberFromGroup(group.id, m.userId);
                                ref.invalidate(veladaGroupMembersProvider(group.id));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  TextButton.icon(
                    onPressed: () => _showAddMemberDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir Jugador manualmente'),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) =>
                Padding(padding: EdgeInsets.all(16), child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
