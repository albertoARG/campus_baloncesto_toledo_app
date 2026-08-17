import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';
import '../../../../../core/sync/sync_queue.dart';
import '../../../../../core/widgets/quick_number_field.dart';

class AddFreeThrowDialog extends ConsumerStatefulWidget {
  final String competitionId;
  const AddFreeThrowDialog({super.key, required this.competitionId});

  @override
  ConsumerState<AddFreeThrowDialog> createState() => _AddFreeThrowDialogState();
}

class _AddFreeThrowDialogState extends ConsumerState<AddFreeThrowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _puntosController = TextEditingController();
  
  String? _selectedUserId;
  bool _isLoading = false;

  @override
  void dispose() {
    _puntosController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un jugador')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final puntos = int.parse(_puntosController.text);
      final uploaded = await ref.read(syncQueueProvider).addSiestaDailyScore(
            widget.competitionId,
            _selectedUserId!,
            puntos,
            DateTime.now(),
            label: 'Tiros libres · $puntos',
          );

      ref.invalidate(siestaDailyScoresProvider(widget.competitionId));
      ref.invalidate(siestaParticipantsProvider(widget.competitionId));
      if (mounted) {
        if (!uploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Sin conexión: guardado. Se subirá al recuperar la conexión.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(allPlayersSiestaProvider);

    return AlertDialog(
      title: const Text('Nuevo Intento Tiros Libres'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            playersAsync.when(
              data: (players) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Jugador', border: OutlineInputBorder()),
                  value: _selectedUserId,
                  items: players.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.nombre} ${p.apellidos}'),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedUserId = val),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => const Text('Error cargando jugadores'),
            ),
            const SizedBox(height: 16),
            QuickNumberField(
              controller: _puntosController,
              label: 'Tiros anotados',
              quickAdds: const [1, 5],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
        )
      ],
    );
  }
}
