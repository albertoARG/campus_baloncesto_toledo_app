import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/live_match_model.dart';
import '../../data/models/match_team_model.dart';
import '../../data/repositories/matches_repository.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository(ref.watch(supabaseClientProvider));
});

/// Equipos creados específicamente para los partidos (no son los grupos de
/// competición y no cuentan en la clasificación).
final matchTeamsProvider = FutureProvider<List<MatchTeamModel>>((ref) {
  return ref.watch(matchesRepositoryProvider).getTeams();
});

/// Lista de partidos en tiempo real.
final matchesStreamProvider = StreamProvider<List<LiveMatchModel>>((ref) {
  return ref.watch(matchesRepositoryProvider).watchMatches();
});

/// Un partido concreto, derivado del stream de la lista (sin abrir otra
/// suscripción). Se actualiza en vivo igual que la lista.
final singleMatchProvider =
    Provider.family<LiveMatchModel?, String>((ref, id) {
  final list = ref.watch(matchesStreamProvider).value ?? [];
  for (final m in list) {
    if (m.id == id) return m;
  }
  return null;
});
