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
  String? _selectedPartnerId;
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
    if (_selectedPartnerId != null && _selectedPartnerId == _selectedUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La pareja no puede ser el mismo jugador')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(siestaRepositoryProvider);
      final grupo = _grupoController.text.trim();
      await repository.addParticipant(
        widget.competitionId,
        _selectedUserId!,
        partnerUserId: _selectedPartnerId,
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
                String label(dynamic p) =>
                    '${p.nombre} ${p.apellidos}${p.role == 'entrenador' ? ' (entrenador)' : ''}';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Jugador', border: OutlineInputBorder()),
                      value: _selectedUserId,
                      items: players.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          label(p),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedUserId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pareja (opcional, ej: mus o futbolín)',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedPartnerId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin pareja (individual)'),
                        ),
                        ...players
                            .where((p) => p.id != _selectedUserId)
                            .map((p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(
                                    label(p),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                      ],
                      onChanged: (val) => setState(() => _selectedPartnerId = val),
                    ),
                  ],
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
