
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../data/models/training_model.dart';
import '../providers/trainings_providers.dart';
import '../../../../core/services/cloudinary_service.dart';

class CreateTrainingScreen extends ConsumerStatefulWidget {
  final TrainingModel? training;

  const CreateTrainingScreen({super.key, this.training});

  @override
  ConsumerState<CreateTrainingScreen> createState() => _CreateTrainingScreenState();
}

class _CreateTrainingScreenState extends ConsumerState<CreateTrainingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _selectedTeamId;
  DateTime? _selectedDate;
  bool _isLoading = false;
  
  List<String> _existingUrls = [];
  List<XFile> _newMedia = [];
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool get isEdit => widget.training != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final t = widget.training!;
      _tituloController.text = t.titulo;
      if (t.descripcion != null) _descController.text = t.descripcion!;
      if (t.multimediaUrl != null) {
        _existingUrls = t.multimediaUrl!.split(',').where((e) => e.trim().isNotEmpty).toList();
      }
      _selectedTeamId = t.teamId;
      _selectedDate = t.fecha;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickGalleryImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> media = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (media.isNotEmpty) {
      setState(() {
        _newMedia.addAll(media);
      });
    }
  }

  Future<void> _pickCameraImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (media != null) {
      setState(() {
        _newMedia.add(media);
      });
    }
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la Galería (varias)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickGalleryImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCameraImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProfileProvider).value;
      
      List<String> finalUrls = List.from(_existingUrls);

      // Si seleccionó archivos locales, subirlos a Cloudinary
      if (_newMedia.isNotEmpty) {
        for (var file in _newMedia) {
          final uploadedUrl = await _cloudinaryService.uploadImage(file);
          if (uploadedUrl != null) {
            finalUrls.add(uploadedUrl);
          } else {
            throw Exception('Error al subir una de las imágenes a Cloudinary');
          }
        }
      }
      
      final String? combinedUrl = finalUrls.isEmpty ? null : finalUrls.join(',');

      final training = TrainingModel(
        id: isEdit ? widget.training!.id : '', // Supabase generará el ID si es nuevo
        titulo: _tituloController.text.trim(),
        descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        multimediaUrl: combinedUrl,
        fecha: _selectedDate,
        teamId: _selectedTeamId,
        coachId: isEdit ? widget.training!.coachId : user?.id,
      );

      if (isEdit) {
        await ref.read(trainingsRepositoryProvider).updateTraining(training.id, training);
      } else {
        await ref.read(trainingsRepositoryProvider).createTraining(training);
      }
      ref.invalidate(trainingsProvider);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Entrenamiento actualizado' : 'Entrenamiento creado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar Entrenamiento' : 'Crear Entrenamiento')),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Guardando...\n(Puede tardar si incluye multimedia)'),
              ],
            ),
          )
        : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título del Entrenamiento *'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fotos de la Pizarra / Jugadas', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo, color: Colors.indigo),
                    onPressed: _showMediaSourceDialog,
                    tooltip: 'Adjuntar Fotos',
                  ),
                ],
              ),
              if (_existingUrls.isNotEmpty || _newMedia.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._existingUrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8, top: 8),
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(CloudinaryService.optimizedUrl(url, width: 400)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _existingUrls.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      ..._newMedia.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8, top: 8),
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(file.path), // Para Flutter Web, XFile.path es un objectUrl válido. O NetworkImage(file.path) / FileImage no funciona igual en Web.
                                  // Wait, for Web, XFile.path works with Image.network
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _newMedia.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_selectedDate == null 
                  ? 'Seleccionar Fecha' 
                  : 'Fecha: ${_selectedDate!.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              groupsAsync.when(
                data: (groups) {
                  return DropdownButtonFormField<String>(
                    value: _selectedTeamId,
                    decoration: const InputDecoration(labelText: 'Asignar a Grupo/Equipo (Opcional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Para todos (General)')),
                      ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nombre)))
                    ],
                    onChanged: (val) => setState(() => _selectedTeamId = val),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error al cargar grupos: $e'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: Text(isEdit ? 'Guardar Cambios' : 'Crear Entrenamiento'),
              )
            ],
          ),
        ),
    );
  }
}

