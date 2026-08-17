import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/velada_model.dart';
import '../providers/veladas_providers.dart';
import '../../data/models/velada_group_model.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../../core/widgets/search_field.dart';

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
                ref.invalidate(veladaAssignedUsersProvider(velada.id));
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              final groups =
                  ref.read(veladaGroupsProvider(velada.id)).value;
              ref.invalidate(veladaGroupsProvider(velada.id));
              ref.invalidate(veladaAssignedUsersProvider(velada.id));
              if (groups != null) {
                for (final g in groups) {
                  ref.invalidate(veladaGroupMembersProvider(g.id));
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
      builder: (context) =>
          _AddVeladaMemberSheet(veladaId: veladaId, groupId: group.id),
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
                  ? Colors.amber.withValues(alpha: 0.22)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                group.isWinner ? Colors.amber.shade900 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(
                    Icons.emoji_events,
                    size: 18,
                    color: group.isWinner ? Colors.black87 : null,
                  ),
                  label: const Text('Ganador'),
                  selected: group.isWinner,
                  selectedColor: Colors.amber,
                  showCheckmark: false,
                  onSelected: (v) async {
                    await ref
                        .read(veladasRepositoryProvider)
                        .setGroupWinner(group.id, v);
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
                      label: const Text('Añadir Jugador manualmente'),
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
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Quitar del grupo'),
                                    content: Text(
                                        '¿Seguro que quieres sacar a ${m.user?.nombre ?? 'este jugador'} ${m.user?.apellidos ?? ''} de este grupo?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitar', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                await ref.read(veladasRepositoryProvider).removeMemberFromGroup(group.id, m.userId);
                                ref.invalidate(veladaGroupMembersProvider(group.id));
                                ref.invalidate(veladaAssignedUsersProvider(veladaId));
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

/// Hoja para añadir un jugador a un grupo: oculta a los que ya están en otro
/// equipo de la velada y permite buscar escribiendo.
class _AddVeladaMemberSheet extends ConsumerStatefulWidget {
  final String veladaId;
  final String groupId;
  const _AddVeladaMemberSheet({required this.veladaId, required this.groupId});

  @override
  ConsumerState<_AddVeladaMemberSheet> createState() =>
      _AddVeladaMemberSheetState();
}

class _AddVeladaMemberSheetState extends ConsumerState<_AddVeladaMemberSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final assignedAsync =
        ref.watch(veladaAssignedUsersProvider(widget.veladaId));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Añadir Jugador',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SearchField(
                hintText: 'Buscar por nombre…',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: usersAsync.when(
                  data: (users) {
                    final assigned = assignedAsync.value ?? <String>{};
                    final q = _query.trim().toLowerCase();
                    final eligible = users
                        .where((u) =>
                            (u.role == 'jugador' || u.role == 'visitante') &&
                            !assigned.contains(u.id) &&
                            (q.isEmpty ||
                                '${u.nombre} ${u.apellidos}'
                                    .toLowerCase()
                                    .contains(q)))
                        .toList()
                      ..sort((a, b) => '${a.nombre} ${a.apellidos}'
                          .toLowerCase()
                          .compareTo(
                              '${b.nombre} ${b.apellidos}'.toLowerCase()));

                    if (eligible.isEmpty) {
                      return Center(
                        child: Text(assignedAsync.isLoading
                            ? 'Cargando…'
                            : 'No hay jugadores disponibles (todos están ya en un equipo).'),
                      );
                    }
                    return ListView.builder(
                      itemCount: eligible.length,
                      itemBuilder: (context, index) {
                        final user = eligible[index];
                        return ListTile(
                          title: Text('${user.nombre} ${user.apellidos}'),
                          subtitle: Text('Edad: ${user.edad ?? "?"}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(veladasRepositoryProvider)
                                    .addMemberToGroup(widget.groupId, user.id);
                                ref.invalidate(
                                    veladaGroupMembersProvider(widget.groupId));
                                ref.invalidate(veladaAssignedUsersProvider(
                                    widget.veladaId));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${user.nombre} añadido'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
