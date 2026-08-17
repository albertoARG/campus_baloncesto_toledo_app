import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/training_model.dart';
import '../../data/models/training_plan_data.dart';
import '../../data/services/training_template_service.dart';
import 'play_view.dart';
import 'package:intl/intl.dart';
import 'package:campus_baloncesto_app/core/services/cloudinary_service.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import 'create_training_screen.dart';

class TrainingDetailScreen extends ConsumerWidget {
  final TrainingModel training;

  const TrainingDetailScreen({super.key, required this.training});

  void _showFullScreenImages(BuildContext context, List<String> urls, int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text('${initialIndex + 1} / ${urls.length}'),
          ),
          body: PageView.builder(
            controller: pageController,
            itemCount: urls.length,
            onPageChanged: (index) {
              // Option to update title here via StatefulBuilder or just leave as is for simplicity
            },
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    CloudinaryService.optimizedUrl(urls[index], width: 1600),
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.white, size: 50),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fichaWidget(BuildContext context, TrainingPlanData p) {
    Widget chip(String k, String v) => v.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(right: 14, bottom: 6),
            child: Text('$k: $v',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ficha de sesión',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(children: [
          chip('Día', p.dia),
          chip('Hora', p.hora),
          chip('Duración', p.duracion),
          chip('Lugar', p.lugar),
          chip('Sesión Nº', p.sesion),
        ]),
        if (p.objetivos.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Objetivos: ${p.objetivos}'),
        ],
        if (p.ejercicios.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Ejercicios',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...p.ejercicios.asMap().entries.map((e) {
            final i = e.key;
            final ex = e.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(ex.nombre.isEmpty ? '(sin nombre)' : ex.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    ex.descripcion.isEmpty ? null : Text(ex.descripcion),
                trailing: ex.tiempo.isEmpty
                    ? null
                    : Text(ex.tiempo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ],
        if (p.asistentes.trim().isNotEmpty || p.ausentes.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          if (p.asistentes.trim().isNotEmpty)
            Text('Asistentes: ${p.asistentes}'),
          if (p.ausentes.trim().isNotEmpty) Text('Ausentes: ${p.ausentes}'),
        ],
        if (p.jugadas.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Jugadas',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...p.jugadas.map((play) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (play.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(play.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: AnimatedPlayView(play: play),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String role = userProfileAsync.value?.role ?? 'visitante';
    final bool canManage = role == 'admin' || role == 'entrenador';
    
    List<String> imageUrls = [];
    if (training.multimediaUrl != null && training.multimediaUrl!.isNotEmpty) {
      imageUrls = training.multimediaUrl!.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    final plan = TrainingPlanData.tryParse(training.descripcion);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Entrenamiento'),
        actions: [
          if (plan != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Descargar ficha en PDF',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando PDF…')),
                );
                try {
                  await TrainingTemplateService()
                      .printFilled(training.titulo, plan);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTrainingScreen(training: training),
                  ),
                ).then((_) {
                  if (context.mounted) Navigator.pop(context); // Optional: Pop detail screen to refresh data in list
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              training.titulo,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  training.fecha != null 
                    ? DateFormat('dd/MM/yyyy').format(training.fecha!) 
                    : 'Fecha no especificada',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.group, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Grupo: ${training.team?.nombre ?? 'General'}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (plan != null) ...[
              _fichaWidget(context, plan),
              const SizedBox(height: 24),
            ] else if (training.descripcion != null &&
                training.descripcion!.isNotEmpty) ...[
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                training.descripcion!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
            ],
            if (imageUrls.isNotEmpty) ...[
              const Text(
                'Material Adjunto / Pizarra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    final url = imageUrls[index];
                    return GestureDetector(
                      onTap: () => _showFullScreenImages(context, imageUrls, index),
                      child: Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            CloudinaryService.optimizedUrl(url, width: 800),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pulsa una imagen para verla en pantalla completa (${imageUrls.length} fotos)',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
