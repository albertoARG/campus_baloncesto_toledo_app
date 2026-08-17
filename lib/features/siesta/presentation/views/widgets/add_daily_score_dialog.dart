import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';
import '../../../../../core/sync/sync_queue.dart';
import '../../../../../core/widgets/quick_number_field.dart';

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
      final puntos = int.parse(_puntosController.text);
      final uploaded = await ref.read(syncQueueProvider).addSiestaDailyScore(
            widget.competitionId,
            widget.userId,
            puntos,
            DateTime.now(),
            label: '${widget.participantName} · $puntos pts',
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
            QuickNumberField(
              controller: _puntosController,
              label: 'Puntos a sumar',
              quickAdds: const [1, 3, 5],
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
