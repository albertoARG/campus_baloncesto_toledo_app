import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/providers/auth_providers.dart';
import '../providers/training_plans_providers.dart';
import '../../data/models/training_plan_model.dart';

class TrainingPlansScreen extends ConsumerWidget {
  const TrainingPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String role = userProfileAsync.value?.role ?? 'visitante';
    final bool canManage = role == 'admin' || role == 'entrenador';

    // Solo entrenadores y admins pueden ver esta pantalla.
    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planificaciones')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo los entrenadores y administradores pueden ver las planificaciones.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final plansAsync = ref.watch(trainingPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(trainingPlansProvider),
          ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trainingPlansProvider);
              await ref.read(trainingPlansProvider.future);
            },
            child: plans.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text('No hay planificaciones subidas todavía.'),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 36,
                          ),
                          title: Text(
                            plan.titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            plan.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openPlan(context, plan),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, plan),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _uploadPlan(context, ref),
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir PDF'),
      ),
    );
  }

  Future<void> _openPlan(
    BuildContext context,
    TrainingPlanModel plan,
  ) async {
    final uri = Uri.parse(plan.url);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el PDF')),
      );
    }
  }

  Future<void> _uploadPlan(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    // Título por defecto: el nombre del archivo sin la extensión.
    final defaultTitle = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final titulo = await _askTitle(context, defaultTitle);
    if (titulo == null || titulo.trim().isEmpty) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(trainingPlansRepositoryProvider).uploadPlan(
            titulo: titulo.trim(),
            bytes: bytes,
            filename: file.name,
          );
      ref.invalidate(trainingPlansProvider);
      if (context.mounted) {
        Navigator.of(context).pop(); // cierra el loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Planificación subida correctamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // cierra el loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e')),
        );
      }
    }
  }

  Future<String?> _askTitle(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Título de la planificación'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Planificación enero'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Subir'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TrainingPlanModel plan,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar la planificación "${plan.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(trainingPlansRepositoryProvider).deletePlan(plan);
      ref.invalidate(trainingPlansProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }
}
