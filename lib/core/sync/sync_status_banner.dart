import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_queue.dart';

/// Banner que avisa cuando no hay conexión o hay resultados pendientes de subir.
/// No ocupa espacio cuando todo está sincronizado y con conexión.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(syncQueueProvider);
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) => _buildBanner(queue),
    );
  }

  Widget _buildBanner(SyncQueue queue) {
    final pending = queue.pendingCount;
    final offline = !queue.isOnline;

    if (pending == 0 && !offline) return const SizedBox.shrink();

    final Color color =
        pending > 0 ? Colors.orange.shade800 : Colors.blueGrey.shade700;
    final String text = pending > 0
        ? '$pending resultado${pending == 1 ? '' : 's'} sin subir'
            '${offline ? ' · sin conexión' : ''}'
        : 'Sin conexión';

    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off : Icons.cloud_upload_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            if (pending > 0)
              TextButton(
                onPressed: () => queue.flush(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
