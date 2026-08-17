import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_providers.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/search_field.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Usuarios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(allUsersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchField(
            hintText: 'Buscar por nombre o rol…',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final q = _query.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? users
                    : users
                          .where(
                            (u) => '${u.nombre} ${u.apellidos} ${u.role}'
                                .toLowerCase()
                                .contains(q),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay usuarios que coincidan.'),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allUsersProvider);
                    await ref.read(allUsersProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final detalles = <String>[
                        'Rol: ${user.role}',
                        if (user.posicion != null && user.posicion!.isNotEmpty)
                          user.posicion!,
                        if (user.edad != null) '${user.edad} años',
                        if (user.nivel != null) 'Nivel ${user.nivel}',
                      ].join(' · ');
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.nombre.isNotEmpty
                                ? user.nombre[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text('${user.nombre} ${user.apellidos}'),
                        subtitle: Text(detalles),
                        onTap: () =>
                            context.push('/admin/users/edit', extra: user),
                        trailing: PopupMenuButton<String>(
                          onSelected: (newRole) async {
                            try {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .updateUserRole(user.id, newRole);
                              ref.invalidate(allUsersProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Rol de ${user.nombre} actualizado a $newRole',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error al actualizar rol: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            const PopupMenuItem(
                              value: 'entrenador',
                              child: Text('Entrenador'),
                            ),
                            const PopupMenuItem(
                              value: 'jugador',
                              child: Text('Jugador'),
                            ),
                            const PopupMenuItem(
                              value: 'jugador premium',
                              child: Text('Jugador Premium'),
                            ),
                            const PopupMenuItem(
                              value: 'familiar',
                              child: Text('Familiar'),
                            ),
                            const PopupMenuItem(
                              value: 'visitante',
                              child: Text('Visitante'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SkeletonList(),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
