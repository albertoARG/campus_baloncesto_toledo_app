import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/blog_providers.dart';
import '../../../../features/blog/data/models/blog_post_model.dart';

class EditBlogPostScreen extends ConsumerWidget {
  final String postId;

  const EditBlogPostScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(blogPostsProvider);

    return postsAsync.when(
      data: (posts) {
        final post = posts.firstWhere(
          (p) => p.id == postId,
          orElse: () => posts.first,
        );
        return EditBlogPostScreenInner(post: post);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class EditBlogPostScreenInner extends ConsumerStatefulWidget {
  final BlogPostModel post;

  const EditBlogPostScreenInner({super.key, required this.post});

  @override
  ConsumerState<EditBlogPostScreenInner> createState() => _EditBlogPostScreenInnerState();
}

class _EditBlogPostScreenInnerState extends ConsumerState<EditBlogPostScreenInner> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // Fotos de galería existentes que el usuario NO ha eliminado
  late List<String> _keepExistingImages;
  // Fotos nuevas seleccionadas del dispositivo
  final List<XFile> _newGalleryImages = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content);
    // Inicializamos con las fotos de galería actuales (imageUrls, NO la portada)
    _keepExistingImages = List<String>.from(widget.post.imageUrls ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickGalleryImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newGalleryImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imágenes: $e')),
        );
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _keepExistingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newGalleryImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(blogRepositoryProvider)
          .updatePost(
            id: widget.post.id,
            title: _titleController.text,
            content: _contentController.text,
            existingImageUrls: _keepExistingImages,
            newGalleryImages: _newGalleryImages,
          );

      // Invalidar y esperar a que los datos nuevos estén listos
      // ignore: unused_result
      ref.invalidate(blogPostsProvider);
      await ref.read(blogPostsProvider.future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrada actualizada correctamente')),
        );
        // Reemplazamos la ruta en el historial del navegador para que Edit desaparezca
        context.replace('/blog');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGallery =
        _keepExistingImages.isNotEmpty || _newGalleryImages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Entrada')),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Guardando cambios...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Portada (solo muestra, no se puede cambiar aquí) ──────
                    if (widget.post.imageUrl.isNotEmpty) ...[
                      Text(
                        'Foto de portada',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.post.imageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 160,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (c, u, e) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Título ───────────────────────────────────────────────
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Contenido ────────────────────────────────────────────
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Contenido',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Galería ──────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Galería de fotos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: _pickGalleryImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Añadir fotos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (!hasGallery)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No hay fotos en la galería.\nPulsa "Añadir fotos" para incluir algunas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),

                    if (hasGallery)
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Fotos existentes (con X roja para eliminar)
                            ..._keepExistingImages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final url = entry.value;
                              return _buildImageTile(
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (c, u, e) =>
                                      const Icon(Icons.broken_image),
                                ),
                                label: 'Subida',
                                onRemove: () => _removeExistingImage(index),
                              );
                            }),

                            // Fotos nuevas (con X roja para eliminar)
                            ..._newGalleryImages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final file = entry.value;
                              return _buildImageTile(
                                child: Image.file(
                                  File(file.path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                                label: 'Nueva',
                                onRemove: () => _removeNewImage(index),
                                isNew: true,
                              );
                            }),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // ── Botón guardar ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: _submit,
                        child: const Text('Guardar Cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageTile({
    required Widget child,
    required String label,
    required VoidCallback onRemove,
    bool isNew = false,
  }) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10, top: 8),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isNew
                ? Border.all(color: Colors.blue.shade400, width: 2)
                : Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
        // Badge "Nueva" para fotos recién añadidas
        if (isNew)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Text(
                'Nueva',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        // Botón X para eliminar
        Positioned(
          top: 0,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
