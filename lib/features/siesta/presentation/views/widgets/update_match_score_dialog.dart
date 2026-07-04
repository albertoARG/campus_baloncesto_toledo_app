import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/siesta_providers.dart';
import '../../../data/models/siesta_match_model.dart';

class UpdateMatchScoreDialog extends ConsumerStatefulWidget {
  final SiestaMatchModel match;
  final String competitionId;
  const UpdateMatchScoreDialog({super.key, required this.match, required this.competitionId});

  @override
  ConsumerState<UpdateMatchScoreDialog> createState() => _UpdateMatchScoreDialogState();
}

class _UpdateMatchScoreDialogState extends ConsumerState<UpdateMatchScoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _score1Controller;
  late TextEditingController _score2Controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _score1Controller = TextEditingController(text: widget.match.score1.toString());
    _score2Controller = TextEditingController(text: widget.match.score2.toString());
  }

  @override
  void dispose() {
    _score1Controller.dispose();
    _score2Controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(siestaRepositoryProvider);
      final score1 = int.parse(_score1Controller.text);
      final score2 = int.parse(_score2Controller.text);
      
      await repository.updateMatchScore(widget.match.id, score1, score2);
      
      ref.invalidate(siestaMatchesProvider(widget.competitionId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar partido'),
        content: const Text('¿Estás seguro de que deseas eliminar este partido? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(siestaRepositoryProvider);
      await repository.deleteMatch(widget.match.id);
      
      ref.invalidate(siestaMatchesProvider(widget.competitionId));
      if (mounted) Navigator.pop(context, true); // Return true to refresh parent
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch participants to show names correctly
    final participantsAsync = ref.watch(siestaParticipantsProvider(widget.competitionId));
    
    return AlertDialog(
      title: const Text('Actualizar Resultado'),
      content: participantsAsync.when(
        data: (participants) {
          final p1 = participants.firstWhere((p) => p.id == widget.match.participant1Id);
          final p2 = participants.firstWhere((p) => p.id == widget.match.participant2Id);
          final p1Name = p1.shortDisplayName;
          final p2Name = p2.shortDisplayName;

          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p1Name, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 50,
                        child: TextFormField(
                          controller: _score1Controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? '?' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: TextFormField(
                          controller: _score2Controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? '?' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(p2Name, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (e, s) => Text('Error: $e'),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _deleteMatch, 
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 36)),
              child: const Text('Borrar', style: TextStyle(color: Colors.red)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Cancelar')
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
                ),
              ],
            ),
          ],
        )
      ],
    );
  }
}
