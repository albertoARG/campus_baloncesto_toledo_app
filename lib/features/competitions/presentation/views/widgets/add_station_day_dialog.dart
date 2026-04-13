import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/competitions_providers.dart';

class AddStationDayDialog extends ConsumerStatefulWidget {
  const AddStationDayDialog({super.key});

  @override
  ConsumerState<AddStationDayDialog> createState() => _AddStationDayDialogState();
}

class _AddStationDayDialogState extends ConsumerState<AddStationDayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(competitionsRepositoryProvider);
      await repo.createStationDay(_nombreController.text.trim(), _selectedDate);
      ref.invalidate(stationDaysProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Día añadido')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Día'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre (Ej: Día 1, Lunes)'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_selectedDate == null ? 'Seleccionar Fecha (Opcional)' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
