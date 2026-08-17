import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:excel/excel.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/utils/file_upload.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/search_field.dart';
import '../providers/admin_providers.dart';

/// Gestión de jugadores para admin/entrenador: crear, eliminar e importar
/// desde un Excel de nombres.
class PlayerManagementScreen extends ConsumerStatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  ConsumerState<PlayerManagementScreen> createState() =>
      _PlayerManagementScreenState();
}

class _PlayerManagementScreenState
    extends ConsumerState<PlayerManagementScreen> {
  bool _importing = false;
  String _query = '';

  // Jugadores ocultos temporalmente mientras corre la ventana de "deshacer".
  final Set<String> _pendingDeleteIds = {};

  String _cellText(Data? cell) {
    final v = cell?.value;
    if (v is TextCellValue) return v.value.text ?? '';
    return v?.toString() ?? '';
  }

  bool _looksLikeHeader(String s) {
    final l = s.toLowerCase();
    return l.contains('nombre') ||
        l.contains('alumno') ||
        l.contains('apellido') ||
        l.contains('jugador');
  }

  Future<void> _deletePlayer(UserModel p) async {
    // Se oculta de la lista y se dan 5 s para deshacer antes de borrarlo de
    // verdad. Si se deshace, no se toca la base de datos.
    setState(() => _pendingDeleteIds.add(p.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('${p.nombre} ${p.apellidos} eliminado'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'DESHACER', onPressed: () {}),
      ),
    );

    final reason = await controller.closed;
    if (!mounted) return;

    if (reason == SnackBarClosedReason.action) {
      // Deshacer: vuelve a aparecer, no se borra nada.
      setState(() => _pendingDeleteIds.remove(p.id));
      return;
    }

    try {
      await ref.read(adminRepositoryProvider).deletePlayer(p.id);
      ref.invalidate(allUsersProvider);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(p.id));
    }
  }

  Future<void> _importFromExcel() async {
    final picked = await pickFile(['xlsx']);
    if (picked == null) return;
    final bytes = picked.bytes;

    // Leer nombres: primera celda no vacía de cada fila de la primera hoja.
    List<String> names = [];
    try {
      final excel = Excel.decodeBytes(bytes);
      for (final key in excel.tables.keys) {
        final sheet = excel.tables[key];
        if (sheet == null) continue;
        for (final row in sheet.rows) {
          for (final cell in row) {
            final s = _cellText(cell).trim();
            if (s.isNotEmpty) {
              names.add(s);
              break;
            }
          }
        }
        break; // solo la primera hoja
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo leer el Excel: $e')));
      }
      return;
    }

    // Normalizar y quitar cabeceras.
    names = names
        .map(
          (n) => n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' '),
        )
        .where((n) => n.isNotEmpty && !_looksLikeHeader(n))
        .toList();

    if (names.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron nombres en el archivo.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Importar jugadores'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se han encontrado ${names.length} nombres. ¿Crear estos jugadores?',
              ),
              const SizedBox(height: 4),
              const Text(
                'La edad y el nivel se podrán ajustar después.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...names
                        .take(25)
                        .map(
                          (n) => Text(
                            '• $n',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    if (names.length > 25)
                      Text(
                        '… y ${names.length - 25} más',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _importing = true);
    try {
      final players = names.map((full) {
        final parts = full.split(' ');
        return {
          'nombre': parts.first,
          'apellidos': parts.length > 1 ? parts.sublist(1).join(' ') : '',
        };
      }).toList();
      final n = await ref.read(adminRepositoryProvider).importPlayers(players);
      ref.invalidate(allUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$n jugadores importados')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Jugadores'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar desde Excel',
            onPressed: _importing ? null : _importFromExcel,
          ),
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
            hintText: 'Buscar jugador…',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: Stack(
              children: [
                usersAsync.when(
                  data: (users) {
                    final q = _query.trim().toLowerCase();
                    final players =
                        users
                            .where(
                              (u) =>
                                  u.role == 'jugador' &&
                                  !_pendingDeleteIds.contains(u.id) &&
                                  (q.isEmpty ||
                                      '${u.nombre} ${u.apellidos}'
                                          .toLowerCase()
                                          .contains(q)),
                            )
                            .toList()
                          ..sort(
                            (a, b) => ('${a.nombre} ${a.apellidos}')
                                .toLowerCase()
                                .compareTo(
                                  ('${b.nombre} ${b.apellidos}').toLowerCase(),
                                ),
                          );
                    if (players.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _query.isNotEmpty
                                ? 'No hay jugadores que coincidan.'
                                : 'No hay jugadores. Añade uno con el botón «+» o impórtalos desde un Excel.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(allUsersProvider);
                        await ref.read(allUsersProvider.future);
                      },
                      child: ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, i) {
                          final p = players[i];
                          final detalles = [
                            if (p.posicion != null && p.posicion!.isNotEmpty)
                              p.posicion!,
                            if (p.edad != null) '${p.edad} años',
                            if (p.nivel != null) 'Nivel ${p.nivel}',
                          ].join(' · ');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                p.nombre.isNotEmpty
                                    ? p.nombre[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text('${p.nombre} ${p.apellidos}'),
                            subtitle: Text(
                              detalles.isEmpty ? 'Sin datos' : detalles,
                            ),
                            onTap: () =>
                                context.push('/admin/users/edit', extra: p),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.grey,
                              ),
                              onPressed: () => _deletePlayer(p),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const SkeletonList(),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
                if (_importing)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/players/new'),
        icon: const Icon(Icons.person_add),
        label: const Text('Añadir jugador'),
      ),
    );
  }
}
