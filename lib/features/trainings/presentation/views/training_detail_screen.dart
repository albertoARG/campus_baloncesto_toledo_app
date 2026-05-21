import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/training_model.dart';
import 'package:intl/intl.dart';
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
                    urls[index],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String role = userProfileAsync.value?.role ?? 'visitante';
    final bool canManage = role == 'admin' || role == 'entrenador';
    
    List<String> imageUrls = [];
    if (training.multimediaUrl != null && training.multimediaUrl!.isNotEmpty) {
      imageUrls = training.multimediaUrl!.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Entrenamiento'),
        actions: [
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
            if (training.descripcion != null && training.descripcion!.isNotEmpty) ...[
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
                            url,
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
