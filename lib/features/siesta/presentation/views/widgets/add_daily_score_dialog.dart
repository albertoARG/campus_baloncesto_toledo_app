import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';

class AddDailyScoreDialog extends ConsumerStatefulWidget {
  final String competitionId;
  final String userId;
  final String participantName;
  
  const AddDailyScoreDialog({
    super.key, 
    required this.competitionId,
    required this.userId,
    required this.participantName,
  });

  @override
  ConsumerState<AddDailyScoreDialog> createState() => _AddDailyScoreDialogState();
}

class _AddDailyScoreDialogState extends ConsumerState<AddDailyScoreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _puntosController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _puntosController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(siestaRepositoryProvider);
      final puntos = int.parse(_puntosController.text);
      await repository.addDailyScore(
        widget.competitionId,
        widget.userId,
        puntos,
        DateTime.now(),
      );
      
      ref.invalidate(siestaDailyScoresProvider(widget.competitionId));
      ref.invalidate(siestaParticipantsProvider(widget.competitionId));
      
      if (mounted) {
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
    return AlertDialog(
      title: const Text('Añadir Puntuación'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participante: ${widget.participantName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _puntosController,
              decoration: const InputDecoration(labelText: 'Puntos a sumar', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Obligatorio';
                if (int.tryParse(val) == null) return 'Debe ser número';
                return null;
              },
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
