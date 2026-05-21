import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Usuarios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: usersAsync.when(
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(user.nombre[0].toUpperCase()),
              ),
              title: Text('${user.nombre} ${user.apellidos}'),
              subtitle: Text('Rol: ${user.role}'),
              trailing: PopupMenuButton<String>(
                onSelected: (newRole) async {
                  try {
                    await ref.read(adminRepositoryProvider).updateUserRole(user.id, newRole);
                    ref.invalidate(allUsersProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rol de ${user.nombre} actualizado a $newRole')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar rol: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'admin', child: Text('Admin')),
                  const PopupMenuItem(value: 'entrenador', child: Text('Entrenador')),
                  const PopupMenuItem(value: 'jugador', child: Text('Jugador')),
                  const PopupMenuItem(value: 'jugador premium', child: Text('Jugador Premium')),
                  const PopupMenuItem(value: 'familiar', child: Text('Familiar')),
                  const PopupMenuItem(value: 'visitante', child: Text('Visitante')),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
