import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/user_model.dart';
import '../providers/admin_providers.dart';

/// Pantalla para que un administrador edite los datos de otro jugador.
class EditUserScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const EditUserScreen({super.key, required this.user});

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _posicionController;
  late final TextEditingController _estaturaController;
  late final TextEditingController _edadController;
  int? _nivel;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nombreController = TextEditingController(text: u.nombre);
    _apellidosController = TextEditingController(text: u.apellidos);
    _posicionController = TextEditingController(text: u.posicion ?? '');
    _estaturaController = TextEditingController(text: u.estatura?.toString() ?? '');
    _edadController = TextEditingController(text: u.edad?.toString() ?? '');
    _nivel = u.nivel;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _posicionController.dispose();
    _estaturaController.dispose();
    _edadController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(adminRepositoryProvider).updateUserData(
            widget.user.id,
            nombre: _nombreController.text.trim(),
            apellidos: _apellidosController.text.trim(),
            posicion: _posicionController.text.trim().isEmpty
                ? null
                : _posicionController.text.trim(),
            estatura: _estaturaController.text.trim().isEmpty
                ? null
                : double.tryParse(_estaturaController.text.trim()),
            edad: _edadController.text.trim().isEmpty
                ? null
                : int.tryParse(_edadController.text.trim()),
            nivel: _nivel,
          );
      ref.invalidate(allUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos del jugador actualizados')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar jugador'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.user.nombre} ${widget.user.apellidos}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('Rol: ${widget.user.role}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apellidosController,
                decoration: const InputDecoration(
                  labelText: 'Apellidos',
                  prefixIcon: Icon(Icons.people_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _posicionController,
                decoration: const InputDecoration(
                  labelText: 'Posición de juego',
                  prefixIcon: Icon(Icons.sports_basketball_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estaturaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Estatura (metros, ej: 1.85)',
                  prefixIcon: Icon(Icons.height),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                    return 'Debe ser un número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _edadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Edad (años)',
                  prefixIcon: Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                    return 'Debe ser un número entero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _nivel,
                decoration: const InputDecoration(
                  labelText: 'Nivel de baloncesto',
                  prefixIcon: Icon(Icons.star_outline),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Nivel 1 - Principiante')),
                  DropdownMenuItem(value: 2, child: Text('Nivel 2 - Intermedio Bajo')),
                  DropdownMenuItem(value: 3, child: Text('Nivel 3 - Intermedio Alto')),
                  DropdownMenuItem(value: 4, child: Text('Nivel 4 - Avanzado')),
                  DropdownMenuItem(value: 5, child: Text('Nivel 5 - Élite')),
                ],
                onChanged: (val) => setState(() => _nivel = val),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
