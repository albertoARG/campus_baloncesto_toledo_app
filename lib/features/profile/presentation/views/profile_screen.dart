import 'package:campus_baloncesto_app/core/models/user_model.dart';
import 'package:campus_baloncesto_app/core/services/cloudinary_service.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool showLogoutInAppBar;
  const ProfileScreen({super.key, this.showLogoutInAppBar = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isUploadingPhoto = false;
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _cloudinaryService = CloudinaryService();
  
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

  Future<void> _changeProfilePhoto(String userId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Cambiar foto de perfil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.camera_alt),
                ),
                title: const Text('Hacer una foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_library),
                ),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      // Upload to Cloudinary
      final imageUrl = await _cloudinaryService.uploadImage(pickedFile);

      if (imageUrl == null) {
        throw Exception('No se pudo subir la imagen');
      }

      // Save URL in Supabase
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('users').update({
        'foto_url': imageUrl,
      }).eq('id', userId);

      // Refresh profile data
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar Sesión'),
                  content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authRepositoryProvider).signOut();
                if (mounted) context.go('/');
              }
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
                  // ─── Avatar con botón de cambiar foto ───────────
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          backgroundImage: user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
                          child: _isUploadingPhoto
                            ? const CircularProgressIndicator(color: Colors.white)
                            : user.fotoUrl == null 
                              ? Icon(Icons.person, size: 55, color: Theme.of(context).colorScheme.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingPhoto ? null : () => _changeProfilePhoto(user.id),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${user.nombre} ${user.apellidos}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.5,
                          fontSize: 12,
                        ),
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
