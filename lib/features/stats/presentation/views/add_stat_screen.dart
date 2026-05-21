import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/stats_providers.dart';

class AddStatScreen extends ConsumerStatefulWidget {
  const AddStatScreen({super.key});

  @override
  ConsumerState<AddStatScreen> createState() => _AddStatScreenState();
}

class _AddStatScreenState extends ConsumerState<AddStatScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUserId;
  final _matchNameCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '0');
  final _reboundsCtrl = TextEditingController(text: '0');
  final _assistsCtrl = TextEditingController(text: '0');
  final _stealsCtrl = TextEditingController(text: '0');
  final _blocksCtrl = TextEditingController(text: '0');
  bool _isMvp = false;

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Para simplificar, cargaremos los usuarios aquí
    // Lo ideal sería tener un usersProvider en el auth module que exponga a todos los jugadores
    // Para este caso, vamos a hacer un query directo o usar un provider de users si existe.
    // Wait, let's fetch users
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Estadísticas')),
      body: FutureBuilder(
        future: ref.read(supabaseClientProvider).from('users').select().eq('role', 'jugador premium'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final users = List<Map<String, dynamic>>.from(snapshot.data as List);
          
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Jugador *'),
                  value: _selectedUserId,
                  items: users.map((u) => DropdownMenuItem(
                    value: u['id'] as String,
                    child: Text('${u['nombre']} ${u['apellidos']}'),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedUserId = val),
                  validator: (v) => v == null ? 'Selecciona un jugador' : null,
                ),
                const SizedBox(height: 16),
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
                      child: const Text('Guardar Estadísticas'),
                    )
              ],
            ),
          );
        }
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
      await ref.read(supabaseClientProvider).from('player_match_stats').insert({
        'user_id': _selectedUserId,
        'match_name': _matchNameCtrl.text.trim().isEmpty ? null : _matchNameCtrl.text.trim(),
        'points': int.parse(_pointsCtrl.text),
        'rebounds': int.parse(_reboundsCtrl.text),
        'assists': int.parse(_assistsCtrl.text),
        'steals': int.parse(_stealsCtrl.text),
        'blocks': int.parse(_blocksCtrl.text),
        'is_mvp': _isMvp,
      });

      ref.invalidate(allStatsProvider);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado correctamente')));
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
