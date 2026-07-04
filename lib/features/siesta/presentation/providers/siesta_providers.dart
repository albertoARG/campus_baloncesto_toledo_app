import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/siesta_repository.dart';
import '../../data/models/siesta_competition_model.dart';
import '../../data/models/siesta_participant_model.dart';
import '../../data/models/siesta_match_model.dart';
import '../../data/models/siesta_daily_score_model.dart';
import '../../../../core/models/user_model.dart';

// REPOSITORY PROVIDER
final siestaRepositoryProvider = Provider<SiestaRepository>((ref) {
  return SiestaRepository(ref.watch(supabaseClientProvider));
});

// COMPETITIONS LIST PROVIDER
final siestaCompetitionsProvider = FutureProvider<List<SiestaCompetitionModel>>(
  (ref) {
    final repository = ref.watch(siestaRepositoryProvider);
    return repository.getCompetitions();
  },
);

// SINGLE COMPETITION PARTICIPANTS PROVIDER
final siestaParticipantsProvider =
    FutureProvider.family<List<SiestaParticipantModel>, String>((
      ref,
      competitionId,
    ) {
      final repository = ref.watch(siestaRepositoryProvider);
      return repository.getParticipants(competitionId);
    });

// SINGLE COMPETITION MATCHES PROVIDER
final siestaMatchesProvider =
    FutureProvider.family<List<SiestaMatchModel>, String>((
      ref,
      competitionId,
    ) async {
      final repository = ref.watch(siestaRepositoryProvider);
      return repository.getMatches(competitionId);
    });

// DAILY SCORES PROVIDER
final siestaDailyScoresProvider =
    FutureProvider.family<List<SiestaDailyScoreModel>, String>((
      ref,
      competitionId,
    ) {
      final repository = ref.watch(siestaRepositoryProvider);
      // Fetching all for now or current day
      return repository.getDailyScores(competitionId);
    });

// ALL PLAYERS (For Admins to assign to competition)
// Incluye tambien entrenadores: en algunos juegos (p.ej. mus) participan.
final allPlayersSiestaProvider = FutureProvider<List<UserModel>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('users')
      .select()
      .inFilter('role', ['jugador', 'entrenador'])
      .order('nombre');
  return (response as List).map((j) => UserModel.fromJson(j)).toList();
});
