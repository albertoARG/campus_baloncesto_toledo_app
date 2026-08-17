import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';
import '../../../../../core/models/user_model.dart';

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
                String label(UserModel p) =>
                    '${p.nombre} ${p.apellidos}${p.role == 'entrenador' ? ' (entrenador)' : ''}';
                final sorted = [...players]..sort((a, b) =>
                    '${a.nombre} ${a.apellidos}'.toLowerCase().compareTo(
                        '${b.nombre} ${b.apellidos}'.toLowerCase()));

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Jugador principal (búsqueda escribiendo).
                    Autocomplete<UserModel>(
                      displayStringForOption: label,
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        if (q.isEmpty) return sorted;
                        return sorted
                            .where((p) => label(p).toLowerCase().contains(q));
                      },
                      onSelected: (p) =>
                          setState(() => _selectedUserId = p.id),
                      fieldViewBuilder:
                          (context, controller, focusNode, _) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Jugador',
                            hintText: 'Escribe un nombre…',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (text) {
                            if (_selectedUserId != null) {
                              final sel = sorted
                                  .where((p) => p.id == _selectedUserId);
                              if (sel.isEmpty || label(sel.first) != text) {
                                setState(() => _selectedUserId = null);
                              }
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Pareja opcional (mus / futbolín). Vacío = individual.
                    Autocomplete<UserModel>(
                      displayStringForOption: label,
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        final base =
                            sorted.where((p) => p.id != _selectedUserId);
                        if (q.isEmpty) return base;
                        return base
                            .where((p) => label(p).toLowerCase().contains(q));
                      },
                      onSelected: (p) =>
                          setState(() => _selectedPartnerId = p.id),
                      fieldViewBuilder:
                          (context, controller, focusNode, _) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Pareja (opcional: mus o futbolín)',
                            hintText: 'Déjalo vacío si es individual',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (text) {
                            if (text.trim().isEmpty) {
                              if (_selectedPartnerId != null) {
                                setState(() => _selectedPartnerId = null);
                              }
                              return;
                            }
                            if (_selectedPartnerId != null) {
                              final sel = sorted
                                  .where((p) => p.id == _selectedPartnerId);
                              if (sel.isEmpty || label(sel.first) != text) {
                                setState(() => _selectedPartnerId = null);
                              }
                            }
                          },
                        );
                      },
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
