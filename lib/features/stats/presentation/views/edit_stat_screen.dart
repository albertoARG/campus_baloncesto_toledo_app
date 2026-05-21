import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/player_stat_model.dart';
import '../providers/stats_providers.dart';

class EditStatScreen extends ConsumerStatefulWidget {
  final PlayerStatModel stat;
  final String userName;

  const EditStatScreen({super.key, required this.stat, required this.userName});

  @override
  ConsumerState<EditStatScreen> createState() => _EditStatScreenState();
}

class _EditStatScreenState extends ConsumerState<EditStatScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _matchNameCtrl;
  late TextEditingController _pointsCtrl;
  late TextEditingController _reboundsCtrl;
  late TextEditingController _assistsCtrl;
  late TextEditingController _stealsCtrl;
  late TextEditingController _blocksCtrl;
  late bool _isMvp;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _matchNameCtrl = TextEditingController(text: widget.stat.matchName ?? '');
    _pointsCtrl = TextEditingController(text: widget.stat.points.toString());
    _reboundsCtrl = TextEditingController(text: widget.stat.rebounds.toString());
    _assistsCtrl = TextEditingController(text: widget.stat.assists.toString());
    _stealsCtrl = TextEditingController(text: widget.stat.steals.toString());
    _blocksCtrl = TextEditingController(text: widget.stat.blocks.toString());
    _isMvp = widget.stat.isMvp;
  }

  @override
  void dispose() {
    _matchNameCtrl.dispose();
    _pointsCtrl.dispose();
    _reboundsCtrl.dispose();
    _assistsCtrl.dispose();
    _stealsCtrl.dispose();
    _blocksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar: ${widget.userName}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _matchNameCtrl,
              decoration: const InputDecoration(labelText: 'Partido/Evento (Opcional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildNumberField('Puntos', _pointsCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildNumberField('Rebotes', _reboundsCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildNumberField('Asistencias', _assistsCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildNumberField('Robos', _stealsCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildNumberField('Tapones', _blocksCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('MVP del Partido'),
              value: _isMvp,
              onChanged: (val) => setState(() => _isMvp = val),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Actualizar Estadísticas'),
                  )
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        if (int.tryParse(v) == null) return 'Número inválido';
        return null;
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'match_name': _matchNameCtrl.text.trim().isEmpty ? null : _matchNameCtrl.text.trim(),
        'points': int.parse(_pointsCtrl.text),
        'rebounds': int.parse(_reboundsCtrl.text),
        'assists': int.parse(_assistsCtrl.text),
        'steals': int.parse(_stealsCtrl.text),
        'blocks': int.parse(_blocksCtrl.text),
        'is_mvp': _isMvp,
      };

      await ref.read(statsRepositoryProvider).updateStat(widget.stat.id, data);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualizado correctamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
