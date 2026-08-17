import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../data/models/training_model.dart';
import '../../data/models/training_plan_data.dart';
import '../../data/models/play_data.dart';
import '../providers/trainings_providers.dart';
import '../../../../core/services/cloudinary_service.dart';
import 'play_editor_screen.dart';
import 'play_view.dart';

/// Fila editable de la tabla de ejercicios de la ficha.
class _ExRow {
  final TextEditingController tiempo;
  final TextEditingController nombre;
  final TextEditingController desc;
  _ExRow([PlanExercise? e])
      : tiempo = TextEditingController(text: e?.tiempo ?? ''),
        nombre = TextEditingController(text: e?.nombre ?? ''),
        desc = TextEditingController(text: e?.descripcion ?? '');
  void dispose() {
    tiempo.dispose();
    nombre.dispose();
    desc.dispose();
  }

  PlanExercise toModel() => PlanExercise(
        tiempo: tiempo.text.trim(),
        nombre: nombre.text.trim(),
        descripcion: desc.text.trim(),
      );
}

class CreateTrainingScreen extends ConsumerStatefulWidget {
  final TrainingModel? training;
  final String? initialTeamId;

  const CreateTrainingScreen({super.key, this.training, this.initialTeamId});

  @override
  ConsumerState<CreateTrainingScreen> createState() =>
      _CreateTrainingScreenState();
}

class _CreateTrainingScreenState extends ConsumerState<CreateTrainingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();

  // Campos de la ficha de sesión.
  final _diaC = TextEditingController();
  final _horaC = TextEditingController();
  final _duracionC = TextEditingController();
  final _lugarC = TextEditingController();
  final _sesionC = TextEditingController();
  final _objetivosC = TextEditingController();
  final _asistentesC = TextEditingController();
  final _ausentesC = TextEditingController();
  final List<_ExRow> _exercises = [];
  final List<Play> _plays = [];

  String? _selectedTeamId;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _dirty = false; // hay cambios sin guardar

  void _markDirty() => _dirty = true;

  List<String> _existingUrls = [];
  final List<XFile> _newMedia = [];
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool get isEdit => widget.training != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final t = widget.training!;
      _tituloController.text = t.titulo;
      _selectedTeamId = t.teamId;
      _selectedDate = t.fecha;
      if (t.multimediaUrl != null) {
        _existingUrls = t.multimediaUrl!
            .split(',')
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }
      final plan = TrainingPlanData.tryParse(t.descripcion);
      if (plan != null) {
        _diaC.text = plan.dia;
        _horaC.text = plan.hora;
        _duracionC.text = plan.duracion;
        _lugarC.text = plan.lugar;
        _sesionC.text = plan.sesion;
        _objetivosC.text = plan.objetivos;
        _asistentesC.text = plan.asistentes;
        _ausentesC.text = plan.ausentes;
        for (final e in plan.ejercicios) {
          _exercises.add(_ExRow(e));
        }
        _plays.addAll(plan.jugadas);
      } else if (t.descripcion != null && t.descripcion!.trim().isNotEmpty) {
        // Compatibilidad: descripción antigua de texto libre.
        _objetivosC.text = t.descripcion!;
      }
    } else {
      _selectedTeamId = widget.initialTeamId;
      _selectedDate = DateTime.now();
    }
    // Empezar con unas filas vacías para escribir cómodo.
    while (_exercises.length < 3) {
      _exercises.add(_ExRow());
    }
    // Detectar cambios sin guardar (para avisar al salir).
    for (final c in [
      _tituloController,
      _diaC,
      _horaC,
      _duracionC,
      _lugarC,
      _sesionC,
      _objetivosC,
      _asistentesC,
      _ausentesC,
      for (final e in _exercises) ...[e.tiempo, e.nombre, e.desc],
    ]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _diaC.dispose();
    _horaC.dispose();
    _duracionC.dispose();
    _lugarC.dispose();
    _sesionC.dispose();
    _objetivosC.dispose();
    _asistentesC.dispose();
    _ausentesC.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _pickGalleryImages() async {
    final picker = ImagePicker();
    final media = await picker.pickMultiImage(
        imageQuality: 80, maxWidth: 1920, maxHeight: 1920);
    if (media.isNotEmpty) {
      setState(() {
        _newMedia.addAll(media);
        _dirty = true;
      });
    }
  }

  Future<void> _pickCameraImage() async {
    final picker = ImagePicker();
    final media = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920);
    if (media != null) {
      setState(() {
        _newMedia.add(media);
        _dirty = true;
      });
    }
  }

  Future<void> _drawPlay([int? editIndex]) async {
    final result = await Navigator.push<Play>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayEditorScreen(
            initial: editIndex != null ? _plays[editIndex] : null),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (editIndex != null) {
          _plays[editIndex] = result;
        } else {
          _plays.add(result);
        }
        _dirty = true;
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

      // Construir la ficha de sesión.
      final ejercicios =
          _exercises.map((e) => e.toModel()).where((e) => !e.isEmpty).toList();
      final plan = TrainingPlanData(
        dia: _diaC.text.trim(),
        hora: _horaC.text.trim(),
        duracion: _duracionC.text.trim(),
        lugar: _lugarC.text.trim(),
        sesion: _sesionC.text.trim(),
        objetivos: _objetivosC.text.trim(),
        asistentes: _asistentesC.text.trim(),
        ausentes: _ausentesC.text.trim(),
        ejercicios: ejercicios,
        jugadas: _plays,
      );
      final planEmpty = plan.dia.isEmpty &&
          plan.hora.isEmpty &&
          plan.duracion.isEmpty &&
          plan.lugar.isEmpty &&
          plan.sesion.isEmpty &&
          plan.objetivos.isEmpty &&
          plan.asistentes.isEmpty &&
          plan.ausentes.isEmpty &&
          ejercicios.isEmpty &&
          _plays.isEmpty;

      // Fotos (opcional).
      final finalUrls = List<String>.from(_existingUrls);
      if (_newMedia.isNotEmpty) {
        for (final file in _newMedia) {
          final url = await _cloudinaryService.uploadImage(file);
          if (url != null) {
            finalUrls.add(url);
          } else {
            throw Exception('Error al subir una de las imágenes');
          }
        }
      }

      final training = TrainingModel(
        id: isEdit ? widget.training!.id : '',
        titulo: _tituloController.text.trim(),
        descripcion: planEmpty ? null : plan.encode(),
        multimediaUrl: finalUrls.isEmpty ? null : finalUrls.join(','),
        fecha: _selectedDate,
        teamId: _selectedTeamId,
        coachId: isEdit ? widget.training!.coachId : user?.id,
      );

      if (isEdit) {
        await ref
            .read(trainingsRepositoryProvider)
            .updateTraining(training.id, training);
      } else {
        await ref.read(trainingsRepositoryProvider).createTraining(training);
      }
      ref.invalidate(trainingsProvider);

      if (mounted) {
        _dirty = false; // guardado: no avisar al salir
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEdit
                  ? 'Entrenamiento actualizado'
                  : 'Entrenamiento creado')),
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

  Widget _smallField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _exerciseRow(int i) {
    final row = _exercises[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, child: Text('${i + 1}')),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: _smallField(row.tiempo, 'Tiempo'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Quitar ejercicio',
                  onPressed: () => setState(() {
                    _exercises.removeAt(i).dispose();
                    _dirty = true;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _smallField(row.nombre, 'Nombre del ejercicio / aspectos'),
            const SizedBox(height: 8),
            TextField(
              controller: row.desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción / observaciones',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Salir sin guardar'),
        content: const Text(
            'Has hecho cambios que no se han guardado. ¿Seguro que quieres salir y perderlos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Seguir editando')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salir sin guardar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_dirty || await _confirmDiscard()) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Editar Entrenamiento' : 'Crear Entrenamiento')),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Guardando…'),
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
                    decoration: const InputDecoration(
                        labelText: 'Título del entrenamiento *',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  groupsAsync.when(
                    data: (groups) => DropdownButtonFormField<String>(
                      value: _selectedTeamId,
                      decoration: const InputDecoration(
                          labelText: 'Grupo / equipo',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Para todos (General)')),
                        ...groups.map((g) => DropdownMenuItem(
                            value: g.id, child: Text(g.nombre))),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedTeamId = val;
                        _dirty = true;
                      }),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error al cargar grupos: $e'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_selectedDate == null
                        ? 'Seleccionar fecha'
                        : 'Fecha: ${_selectedDate!.toLocal().toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _selectDate,
                  ),
                  const Divider(height: 24),

                  // ── Ficha de sesión ──────────────────────────────
                  Text('Ficha de sesión',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _smallField(_diaC, 'Día')),
                      const SizedBox(width: 8),
                      Expanded(child: _smallField(_horaC, 'Hora')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _smallField(_duracionC, 'Duración')),
                      const SizedBox(width: 8),
                      Expanded(child: _smallField(_lugarC, 'Lugar')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _smallField(_sesionC, 'Sesión Nº'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _objetivosC,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Objetivos de la sesión',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Text('Ejercicios',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _exercises.length; i++) _exerciseRow(i),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        final row = _ExRow();
                        row.tiempo.addListener(_markDirty);
                        row.nombre.addListener(_markDirty);
                        row.desc.addListener(_markDirty);
                        _exercises.add(row);
                        _dirty = true;
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir ejercicio'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _smallField(_asistentesC, 'Asistentes')),
                      const SizedBox(width: 8),
                      Expanded(child: _smallField(_ausentesC, 'Ausentes')),
                    ],
                  ),
                  const Divider(height: 24),

                  // ── Fotos (opcional) ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fotos de la pizarra (opcional)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_a_photo, color: Colors.indigo),
                        onPressed: _showMediaSourceDialog,
                        tooltip: 'Adjuntar fotos',
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // ── Jugadas (pizarra) ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jugadas (pizarra)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => _drawPlay(),
                        icon: const Icon(Icons.gesture),
                        label: const Text('Dibujar'),
                      ),
                    ],
                  ),
                  if (_plays.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _plays.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10, top: 8),
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => _drawPlay(i),
                                  child: SizedBox(
                                    height: 130,
                                    child: AnimatedPlayView(play: _plays[i]),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: () => _drawPlay(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.indigo,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.edit,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() {
                                          _plays.removeAt(i);
                                          _dirty = true;
                                        }),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_existingUrls.isNotEmpty || _newMedia.isNotEmpty)
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._existingUrls.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final url = entry.value;
                            return _thumb(
                              NetworkImage(
                                  CloudinaryService.optimizedUrl(url, width: 400)),
                              () => setState(() {
                                    _existingUrls.removeAt(idx);
                                    _dirty = true;
                                  }),
                            );
                          }),
                          ..._newMedia.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final file = entry.value;
                            return _thumb(
                              NetworkImage(file.path),
                              () => setState(() {
                                    _newMedia.removeAt(idx);
                                    _dirty = true;
                                  }),
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(isEdit ? 'Guardar cambios' : 'Crear entrenamiento'),
                  ),
                ],
              ),
            ),
    ),
    );
  }

  Widget _thumb(ImageProvider image, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8),
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration:
                  const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
