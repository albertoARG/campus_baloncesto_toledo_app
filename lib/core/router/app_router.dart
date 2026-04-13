import 'package:campus_baloncesto_app/features/auth/presentation/views/sign_in_screen.dart';
import 'package:campus_baloncesto_app/features/auth/presentation/views/sign_up_screen.dart';
import 'package:campus_baloncesto_app/features/home/presentation/views/home_screen.dart';
import 'package:campus_baloncesto_app/features/admin/presentation/views/user_management_screen.dart';
import 'package:campus_baloncesto_app/features/competitions/presentation/views/standings_screen.dart';
import 'package:campus_baloncesto_app/features/competitions/presentation/views/add_score_screen.dart';
import 'package:campus_baloncesto_app/features/competitions/presentation/views/station_management_screen.dart';
import 'package:campus_baloncesto_app/features/competitions/presentation/views/user_station_scores_screen.dart';
import 'package:campus_baloncesto_app/features/blog/presentation/views/blog_screen.dart';
import 'package:campus_baloncesto_app/features/blog/presentation/views/create_post_screen.dart';
import 'package:campus_baloncesto_app/features/profile/presentation/views/profile_screen.dart';
import 'package:campus_baloncesto_app/features/groups/presentation/views/group_management_screen.dart';
import 'package:campus_baloncesto_app/features/veladas/presentation/views/veladas_management_screen.dart';
import 'package:campus_baloncesto_app/features/veladas/presentation/views/veladas_standings_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/siesta_home_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/create_siesta_competition_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/siesta_league_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/siesta_daily_ladder_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/siesta_free_throws_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/siesta_participant_matches_screen.dart';
import 'package:campus_baloncesto_app/features/siesta/presentation/views/siesta_participant_scores_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const SignInScreen()),
    GoRoute(path: '/register', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/standings', builder: (context, state) => const StandingsScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/blog', builder: (context, state) => const BlogScreen()),
    GoRoute(path: '/blog/create', builder: (context, state) => const CreatePostScreen()),
    GoRoute(path: '/add-score', builder: (context, state) => const AddScoreScreen()),
    GoRoute(path: '/competitions/manage', builder: (context, state) => const StationManagementScreen()),
    GoRoute(
      path: '/competitions/user/:id', 
      builder: (context, state) => UserStationScoresScreen(
        userId: state.pathParameters['id']!,
        userName: state.extra as String? ?? 'Jugador',
      )
    ),
    GoRoute(path: '/veladas', builder: (context, state) => const VeladasStandingsScreen()),
    GoRoute(path: '/admin/users', builder: (context, state) => const UserManagementScreen()),
    GoRoute(path: '/admin/groups', builder: (context, state) => const GroupManagementScreen()),
    GoRoute(path: '/admin/veladas', builder: (context, state) => const VeladasManagementScreen()),
    GoRoute(path: '/siesta', builder: (context, state) => const SiestaHomeScreen()),
    GoRoute(path: '/siesta/create', builder: (context, state) => const CreateSiestaCompetitionScreen()),
    GoRoute(path: '/siesta/league/:id', builder: (context, state) => SiestaLeagueScreen(competitionId: state.pathParameters['id']!)),
    GoRoute(path: '/siesta/daily/:id', builder: (context, state) => SiestaDailyLadderScreen(competitionId: state.pathParameters['id']!)),
    GoRoute(path: '/siesta/freethrows/:id', builder: (context, state) => SiestaFreeThrowsScreen(competitionId: state.pathParameters['id']!)),
    GoRoute(
      path: '/siesta/participant/:comp_id/:part_id',
      builder: (context, state) => SiestaParticipantMatchesScreen(
        competitionId: state.pathParameters['comp_id']!,
        participantId: state.pathParameters['part_id']!,
      ),
    ),
    GoRoute(
      path: '/siesta/participant_scores/:comp_id/:user_id',
      builder: (context, state) => SiestaParticipantScoresScreen(
        competitionId: state.pathParameters['comp_id']!,
        userId: state.pathParameters['user_id']!,
        participantName: state.extra as String? ?? 'Jugador',
      ),
    ),
  ],
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isGoingToAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    // If logged in and going to login/register, send home
    if (session != null && isGoingToAuth) {
      return '/';
    }

    // Note: We are allowing session == null for the root route '/'
    // Other routes can be protected here if needed.

    return null;
  },
);

// Temporary placeholder screen
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Baloncesto')),
      body: const Center(child: Text('Home Screen (Work in progress)')),
    );
  }
}
