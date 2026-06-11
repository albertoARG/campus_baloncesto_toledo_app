import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Datos agregados que muestra el dashboard de administración.
class AdminDashboardData {
  final int jugadores;
  final int entrenadores;
  final int familiares;
  final int visitantes;
  final int equipos;
  final int siestaActivas;
  final int siestaTotal;
  final int siestaPartidosPendientes;
  final int siestaPartidosJugados;
  final int veladas;
  final int blogPosts;
  final int tablonPosts;
  final int entrenamientos;
  final int jornadasEstaciones;

  AdminDashboardData({
    required this.jugadores,
    required this.entrenadores,
    required this.familiares,
    required this.visitantes,
    required this.equipos,
    required this.siestaActivas,
    required this.siestaTotal,
    required this.siestaPartidosPendientes,
    required this.siestaPartidosJugados,
    required this.veladas,
    required this.blogPosts,
    required this.tablonPosts,
    required this.entrenamientos,
    required this.jornadasEstaciones,
  });
}

final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    supabase.from('users').select('role'),
    supabase.from('teams').select('id'),
    supabase.from('siesta_competitions').select('estado'),
    supabase.from('siesta_matches').select('estado'),
    supabase.from('veladas').select('id'),
    supabase.from('blog_posts').select('id'),
    supabase.from('tablon_posts').select('id'),
    supabase.from('trainings').select('id'),
    supabase.from('station_days').select('id'),
  ]);

  final users = results[0] as List;
  int countRole(String role) =>
      users.where((u) => (u['role'] as String?) == role).length;

  final siestaComps = results[2] as List;
  final siestaMatches = results[3] as List;

  return AdminDashboardData(
    jugadores: countRole('jugador') + countRole('jugador premium'),
    entrenadores: countRole('entrenador'),
    familiares: countRole('familiar'),
    visitantes: countRole('visitante'),
    equipos: (results[1] as List).length,
    siestaActivas:
        siestaComps.where((c) => c['estado'] != 'finalizada').length,
    siestaTotal: siestaComps.length,
    siestaPartidosPendientes:
        siestaMatches.where((m) => m['estado'] != 'finalizado').length,
    siestaPartidosJugados:
        siestaMatches.where((m) => m['estado'] == 'finalizado').length,
    veladas: (results[4] as List).length,
    blogPosts: (results[5] as List).length,
    tablonPosts: (results[6] as List).length,
    entrenamientos: (results[7] as List).length,
    jornadasEstaciones: (results[8] as List).length,
  );
});
