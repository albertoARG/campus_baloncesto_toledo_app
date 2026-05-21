import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/group_model.dart';
import '../providers/groups_providers.dart';
import '../../../admin/presentation/providers/admin_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    // Obtenemos todos los usuarios para poder seleccionar
    final usersAsync = ref.watch(allUsersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Añadir Jugador',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: usersAsync.when(
                  data: (users) {
                    // Solo jugadores o visitantes para simplificar, o todos
                    final eligibleUsers = users
                        .where((u) => u.role == 'jugador' || u.role == 'jugador premium' || u.role == 'visitante')
                        .toList();

                    return ListView.builder(
                      itemCount: eligibleUsers.length,
                      itemBuilder: (context, index) {
                        final user = eligibleUsers[index];
                        return ListTile(
                          title: Text('${user.nombre} ${user.apellidos}'),
                          subtitle: Text('${user.posicion ?? 'Sin posición'} • ${user.edad != null ? '${user.edad} años' : 'Edad N/D'} • Nivel ${user.nivel ?? 'N/D'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () async {
                              try {
                                await ref.read(groupsRepositoryProvider).addMemberToGroup(group.id, user.id);
                                ref.invalidate(groupMembersProvider(group.id));
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${user.nombre} añadido al grupo')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(group.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(group.nombre),
        actions: [
          IconButton(
             icon: const Icon(Icons.delete),
             onPressed: () async {
               final confirm = await showDialog<bool>(
                 context: context,
                 builder: (c) => AlertDialog(
                   title: const Text('Eliminar Grupo'),
                   content: const Text('¿Estás seguro de que quieres eliminar este grupo y sacar a todos los miembros de él?'),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                     TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                   ],
                 )
               );

               if (confirm == true) {
                 try {
                   await ref.read(groupsRepositoryProvider).deleteGroup(group.id);
                   ref.invalidate(groupsProvider);
                   if (context.mounted) {
                     Navigator.pop(context); // Volver atrás
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grupo eliminado')));
                   }
                 } catch (e) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                   }
                 }
               }
             },
          )
        ]
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No hay miembros en este grupo aún.'));
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('${member.nombre} ${member.apellidos}'),
                subtitle: Text('${member.posicion ?? 'Sin posición'} • ${member.edad != null ? '${member.edad} años' : 'Edad N/D'} • Nivel ${member.nivel ?? 'N/D'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () async {
                    try {
                      await ref.read(groupsRepositoryProvider).removeMemberFromGroup(group.id, member.id);
                      ref.invalidate(groupMembersProvider(group.id));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${member.nombre} eliminado del grupo')),
                        );
                      }
                    } catch (e) {
                       if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                       }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Añadir Jugador'),
      ),
    );
  }
}
