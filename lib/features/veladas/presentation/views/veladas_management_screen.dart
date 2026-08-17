import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/veladas_providers.dart';
import '../../data/models/velada_model.dart';
import 'velada_detail_screen.dart';

class VeladasManagementScreen extends ConsumerWidget {
  const VeladasManagementScreen({super.key});

  Future<void> _confirmDeleteVelada(
      BuildContext context, WidgetRef ref, VeladaModel velada) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar Velada'),
        content: Text(
            '¿Seguro que quieres borrar "${velada.nombre}" y todos sus grupos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(veladasRepositoryProvider).deleteVelada(velada.id);
      ref.invalidate(allVeladasProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Velada eliminada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateVeladaDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Velada'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nombre (ej: Velada Pirata)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await ref.read(veladasRepositoryProvider).createVelada(nameController.text.trim());
                ref.invalidate(allVeladasProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Velada creada correctamente'))
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veladasAsync = ref.watch(allVeladasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Veladas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(allVeladasProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allVeladasProvider);
          await ref.read(allVeladasProvider.future);
        },
        child: veladasAsync.when(
          data: (veladas) {
            if (veladas.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Aún no se han creado veladas.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: veladas.length,
              itemBuilder: (context, index) {
                final velada = veladas[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                     leading: const Icon(Icons.nightlight_round, color: Colors.indigo),
                     title: Text(velada.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text('Fecha: ${velada.fecha.day}/${velada.fecha.month}/${velada.fecha.year}'),
                     trailing: PopupMenuButton<String>(
                       icon: const Icon(Icons.more_vert),
                       tooltip: 'Opciones',
                       onSelected: (value) {
                         if (value == 'delete') {
                           _confirmDeleteVelada(context, ref, velada);
                         }
                       },
                       itemBuilder: (context) => const [
                         PopupMenuItem(
                           value: 'delete',
                           child: Row(
                             children: [
                               Icon(Icons.delete, color: Colors.red, size: 20),
                               SizedBox(width: 8),
                               Text('Eliminar'),
                             ],
                           ),
                         ),
                       ],
                     ),
                     onTap: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(builder: (_) => VeladaDetailScreen(velada: velada))
                       );
                     },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('Error al cargar veladas: $e')),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateVeladaDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Velada'),
      ),
    );
  }
}
