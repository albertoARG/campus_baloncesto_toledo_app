import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/stats_providers.dart';
import 'add_stat_screen.dart';
import 'player_stats_history_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String role = userProfileAsync.value?.role ?? 'visitante';
    final bool canManage = role == 'admin' || role == 'entrenador';
    final bool isPremium = role == 'jugador premium' || canManage;

    if (!isPremium) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Esta funcionalidad es exclusiva para Jugadores Premium y Staff.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas Deportivas'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: () {
                ref.invalidate(allStatsProvider);
                ref.invalidate(currentUserStatsProvider);
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Ranking Campus'),
              Tab(text: canManage ? 'Jugadores' : 'Mis Estadísticas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _RankingsTab(),
            if (canManage) const _JugadoresTab() else const _MyStatsTab(),
          ],
        ),
        floatingActionButton: canManage
            ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddStatScreen()),
                  );
                },
                child: const Icon(Icons.add),
                tooltip: 'Añadir Estadísticas',
              )
            : null,
      ),
    );
  }
}

class _RankingsTab extends ConsumerWidget {
  const _RankingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(rankingsProvider);

    return rankingsAsync.when(
      data: (rankings) {
        if (rankings.isEmpty) {
          return const Center(child: Text('Aún no hay estadísticas registradas'));
        }

        // Ordenamos y mostramos top 5 o top 10
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRankingCard('Máximo Anotador (Puntos)', rankings, (r) => r.totalPoints, 'PTS'),
            const SizedBox(height: 16),
            _buildRankingCard('Mejor Reboteador', rankings, (r) => r.totalRebounds, 'REB'),
            const SizedBox(height: 16),
            _buildRankingCard('Mejor Asistente', rankings, (r) => r.totalAssists, 'AST'),
            const SizedBox(height: 16),
            _buildRankingCard('MVP del Campus (Galardones)', rankings, (r) => r.mvpAwards, 'MVPs'),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildRankingCard(String title, List<PlayerRanking> rankings, int Function(PlayerRanking) getValue, String unit) {
    final sortedRankings = List<PlayerRanking>.from(rankings)..sort((a, b) => getValue(b).compareTo(getValue(a)));
    // Filter out 0
    final filtered = sortedRankings.where((r) => getValue(r) > 0).take(5).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (filtered.isEmpty)
              const Text('No hay datos suficientes', style: TextStyle(color: Colors.grey))
            else
              ...filtered.asMap().entries.map((entry) {
                final idx = entry.key;
                final r = entry.value;
                final val = getValue(r);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: idx == 0 ? Colors.amber : (idx == 1 ? Colors.grey.shade400 : (idx == 2 ? Colors.brown.shade300 : Colors.indigo.shade100)),
                    child: Text('${idx + 1}º', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${r.user.nombre} ${r.user.apellidos}'),
                  trailing: Text(
                    '$val $unit',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MyStatsTab extends ConsumerWidget {
  const _MyStatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myStatsAsync = ref.watch(currentUserStatsProvider);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    if (userProfile?.role == 'admin' || userProfile?.role == 'entrenador') {
      return const Center(child: Text('Los miembros del staff no tienen estadísticas individuales.'));
    }

    return myStatsAsync.when(
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('Aún no tienes estadísticas registradas'));
        }

        int totalPts = 0;
        int totalReb = 0;
        int totalAst = 0;
        int totalMvp = 0;

        for (var s in stats) {
          totalPts += s.points;
          totalReb += s.rebounds;
          totalAst += s.assists;
          if (s.isMvp) totalMvp++;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Totales del Campus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBox('PTS', totalPts.toString()),
                _StatBox('REB', totalReb.toString()),
                _StatBox('AST', totalAst.toString()),
                _StatBox('MVPs', totalMvp.toString(), color: Colors.amber),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Historial de Partidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...stats.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(s.matchName ?? 'Partido sin nombre'),
                    subtitle: Text('Pts: ${s.points} | Reb: ${s.rebounds} | Ast: ${s.assists} | Rob: ${s.steals} | Tap: ${s.blocks}'),
                    trailing: s.isMvp ? const Icon(Icons.star, color: Colors.amber) : null,
                  ),
                ))
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatBox(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? Theme.of(context).colorScheme.primary),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color ?? Theme.of(context).colorScheme.primary)),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _JugadoresTab extends ConsumerWidget {
  const _JugadoresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(supabaseClientProvider).from('users').select().eq('role', 'jugador premium'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final users = List<Map<String, dynamic>>.from(snapshot.data as List);
        
        if (users.isEmpty) {
          return const Center(child: Text('No hay jugadores registrados.'));
        }
        
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            return ListTile(
              leading: CircleAvatar(child: Text(u['nombre'][0].toString().toUpperCase())),
              title: Text('${u['nombre']} ${u['apellidos']}'),
              subtitle: Text(u['role'].toString().toUpperCase()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerStatsHistoryScreen(
                      userId: u['id'],
                      userName: '${u['nombre']} ${u['apellidos']}',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
