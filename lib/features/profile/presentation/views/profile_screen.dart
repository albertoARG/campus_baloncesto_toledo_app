import 'package:campus_baloncesto_app/core/models/user_model.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool showLogoutInAppBar;
  const ProfileScreen({super.key, this.showLogoutInAppBar = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nombreController;
  late TextEditingController _apellidosController;
  late TextEditingController _posicionController;
  late TextEditingController _estaturaController;
  late TextEditingController _edadController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _apellidosController = TextEditingController();
    _posicionController = TextEditingController();
    _estaturaController = TextEditingController();
    _edadController = TextEditingController();
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

  void _populateControllers(UserModel user) {
    _nombreController.text = user.nombre;
    _apellidosController.text = user.apellidos;
    _posicionController.text = user.posicion ?? '';
    _estaturaController.text = user.estatura?.toString() ?? '';
    _edadController.text = user.edad?.toString() ?? '';
  }

  Future<void> _updateProfile(String userId) async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('users').update({
        'nombre': _nombreController.text.trim(),
        'apellidos': _apellidosController.text.trim(),
        'posicion': _posicionController.text.trim().isEmpty ? null : _posicionController.text.trim(),
        'estatura': _estaturaController.text.trim().isEmpty ? null : double.tryParse(_estaturaController.text.trim()),
        'edad': _edadController.text.trim().isEmpty ? null : int.tryParse(_edadController.text.trim()),
      }).eq('id', userId);

      // Refresh the provider so the UI updates
      ref.invalidate(currentUserProfileProvider);
      
      setState(() {
        _isEditing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el perfil: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
        ),
        actions: [
           IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (user) {
          if (user == null) {
             return const Center(child: Text('No se encontró el perfil del usuario.'));
          }

          if (!_isEditing) {
             _populateControllers(user);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      backgroundImage: user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
                      child: user.fotoUrl == null 
                        ? Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary)
                        : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (user.role == 'admin')
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/admin/users'),
                        icon: const Icon(Icons.manage_accounts),
                        label: const Text('Gestionar Usuarios'),
                      ),
                    ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _nombreController,
                    label: 'Nombre',
                    icon: Icons.person_outline,
                    enabled: _isEditing,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _apellidosController,
                    label: 'Apellidos',
                    icon: Icons.people_outline,
                    enabled: _isEditing,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                   _buildTextField(
                    controller: _posicionController,
                    label: 'Posición de juego',
                    icon: Icons.sports_basketball_outlined,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),
                   _buildTextField(
                    controller: _estaturaController,
                    label: 'Estatura (metros ej: 1.85)',
                    icon: Icons.height,
                    enabled: _isEditing,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                       if (v != null && v.isNotEmpty) {
                         if (double.tryParse(v) == null) return 'Debe ser un número válido';
                       }
                       return null;
                    }
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _edadController,
                    label: 'Edad (años)',
                    icon: Icons.cake_outlined,
                    enabled: _isEditing,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                       if (v != null && v.isNotEmpty) {
                         if (int.tryParse(v) == null) return 'Debe ser un número entero';
                       }
                       return null;
                    }
                  ),
                  const SizedBox(height: 32),
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _updateProfile(user.id),
                        child: const Text('Guardar Cambios'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[200],
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
