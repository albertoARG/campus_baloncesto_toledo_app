import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';

class AddParticipantDialog extends ConsumerStatefulWidget {
  final String competitionId;
  const AddParticipantDialog({super.key, required this.competitionId});

  @override
  ConsumerState<AddParticipantDialog> createState() => _AddParticipantDialogState();
}

class _AddParticipantDialogState extends ConsumerState<AddParticipantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _grupoController = TextEditingController();
  String? _selectedUserId;
  bool _isLoading = false;

  @override
  void dispose() {
    _grupoController.dispose();
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
      final repository = ref.read(siestaRepositoryProvider);
      final grupo = _grupoController.text.trim();
      await repository.addParticipant(
        widget.competitionId,
        _selectedUserId!,
        grupo: grupo.isEmpty ? null : grupo,
      );
      
      ref.invalidate(siestaParticipantsProvider(widget.competitionId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(allPlayersSiestaProvider);

    return AlertDialog(
      title: const Text('Inscribir Participante'),
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
            TextFormField(
              controller: _grupoController,
              decoration: const InputDecoration(labelText: 'Grupo (Opcional, ej: A)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Inscribir'),
        )
      ],
    );
  }
}
