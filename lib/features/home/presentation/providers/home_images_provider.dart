import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Devuelve un mapa clave -> URL con las fotos de la pantalla de inicio que un
/// administrador/entrenador haya personalizado (tabla `home_images`). Si la
/// tabla no existe todavía o no hay filas, devuelve un mapa vacío y la pantalla
/// usa las imágenes por defecto.
final homeImagesProvider = FutureProvider<Map<String, String>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase.from('home_images').select('key, image_url');
    final map = <String, String>{};
    for (final row in (res as List)) {
      final k = row['key'] as String?;
      final u = row['image_url'] as String?;
      if (k != null && u != null && u.isNotEmpty) map[k] = u;
    }
    return map;
  } catch (_) {
    return <String, String>{};
  }
});
