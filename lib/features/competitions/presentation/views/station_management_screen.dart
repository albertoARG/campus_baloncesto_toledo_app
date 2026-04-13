import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/competitions_providers.dart';
import 'widgets/add_station_dialog.dart';
import 'widgets/add_station_day_dialog.dart';

class StationManagementScreen extends ConsumerStatefulWidget {
  const StationManagementScreen({super.key});

  @override
  ConsumerState<StationManagementScreen> createState() => _StationManagementScreenState();
}

class _StationManagementScreenState extends ConsumerState<StationManagementScreen> {
  int _tabIndex = 0; // 0 for Stations, 1 for Days

  void _deleteStation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Estación'),
        content: const Text('¿Seguro? Se borrarán también TODAS las puntuaciones registradas en esta prueba. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (confirm == true) {
      try {
        await ref.read(competitionsRepositoryProvider).deleteStation(id);
        ref.invalidate(stationsProvider);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estación eliminada')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _deleteDay(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Día'),
        content: const Text('¿Seguro? Se borrarán también TODAS las puntuaciones registradas en este día. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (confirm == true) {
      try {
        await ref.read(competitionsRepositoryProvider).deleteStationDay(id);
        ref.invalidate(stationDaysProvider);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Día eliminado')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Gestión de Pruebas y Días'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Pruebas/Estaciones'), icon: Icon(Icons.sports_basketball)),
                ButtonSegment(value: 1, label: Text('Días Obtenidos'), icon: Icon(Icons.calendar_today)),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() => _tabIndex = newSelection.first);
              },
            ),
          ),
          Expanded(
            child: _tabIndex == 0 ? _buildStationsList() : _buildDaysList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabIndex == 0) {
            showDialog(context: context, builder: (_) => const AddStationDialog());
          } else {
            showDialog(context: context, builder: (_) => const AddStationDayDialog());
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabIndex == 0 ? 'Añadir Estación' : 'Añadir Día'),
      ),
    );
  }

  Widget _buildStationsList() {
    final asyncData = ref.watch(stationsProvider);
    return asyncData.when(
      data: (stations) {
        if (stations.isEmpty) return const Center(child: Text('No hay pruebas creadas'));
        return ListView.builder(
          itemCount: stations.length,
          itemBuilder: (ctx, i) {
            final s = stations[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.sports, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s.descripcion ?? 'Sin descripción'),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => _deleteStation(s.id)),
                ),
              ),
            );
          }
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e,s) => Center(child: Text('Error: $e'))
    );
  }

  Widget _buildDaysList() {
    final asyncData = ref.watch(stationDaysProvider);
    return asyncData.when(
      data: (days) {
        if (days.isEmpty) return const Center(child: Text('No hay días creados'));
        return ListView.builder(
          itemCount: days.length,
          itemBuilder: (ctx, i) {
            final d = days[i];
            final f = d.fecha != null ? '${d.fecha!.day}/${d.fecha!.month}/${d.fecha!.year}' : 'Sin fecha configurada';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.secondary),
                  ),
                  title: Text(d.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Fecha real: $f'),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => _deleteDay(d.id)),
                ),
              ),
            );
          }
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e,s) => Center(child: Text('Error: $e'))
    );
  }
}
