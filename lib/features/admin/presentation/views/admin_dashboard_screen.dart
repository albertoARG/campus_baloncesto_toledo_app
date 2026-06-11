import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_dashboard_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final dashboardAsync = ref.watch(adminDashboardProvider);

    if (userProfileAsync.hasValue && userRole != 'admin') {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Dashboard'),
        ),
        body: const Center(
          child: Text('Acceso restringido a administradores.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Dashboard de Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminDashboardProvider);
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle('Personas'),
              _StatGrid(stats: [
                _Stat('Jugadores', data.jugadores, Icons.sports_basketball),
                _Stat('Entrenadores', data.entrenadores, Icons.sports),
                _Stat('Familiares', data.familiares, Icons.family_restroom),
                _Stat('Pendientes de rol', data.visitantes,
                    Icons.person_outline,
                    highlight: data.visitantes > 0),
              ]),
              const SizedBox(height: 20),
              _SectionTitle('Competición'),
              _StatGrid(stats: [
                _Stat('Equipos', data.equipos, Icons.groups),
                _Stat('Jornadas de estaciones', data.jornadasEstaciones,
                    Icons.flag),
                _Stat('Siestas activas', data.siestaActivas,
                    Icons.emoji_events),
                _Stat('Partidos siesta pendientes',
                    data.siestaPartidosPendientes, Icons.schedule,
                    highlight: data.siestaPartidosPendientes > 0),
              ]),
              const SizedBox(height: 20),
              _SectionTitle('Comunidad'),
              _StatGrid(stats: [
                _Stat('Veladas', data.veladas, Icons.auto_awesome),
                _Stat('Entradas de blog', data.blogPosts, Icons.article),
                _Stat('Anuncios en tablón', data.tablonPosts, Icons.campaign),
                _Stat('Entrenamientos', data.entrenamientos,
                    Icons.fitness_center),
              ]),
              const SizedBox(height: 24),
              _SectionTitle('Accesos rápidos'),
              const SizedBox(height: 4),
              _QuickAction(
                icon: Icons.manage_accounts_outlined,
                label: 'Gestionar usuarios y roles',
                subtitle: data.visitantes > 0
                    ? '${data.visitantes} usuario(s) sin rol asignado'
                    : 'Todos los usuarios tienen rol',
                onTap: () => context.push('/admin/users'),
              ),
              _QuickAction(
                icon: Icons.group,
                label: 'Grupos de competición',
                onTap: () => context.push('/admin/groups'),
              ),
              _QuickAction(
                icon: Icons.tune,
                label: 'Gestión de estaciones',
                onTap: () => context.push('/competitions/manage'),
              ),
              _QuickAction(
                icon: Icons.emoji_events,
                label: 'Competiciones de siesta',
                onTap: () => context.push('/siesta'),
              ),
              _QuickAction(
                icon: Icons.auto_awesome,
                label: 'Gestión de veladas',
                onTap: () => context.push('/admin/veladas'),
              ),
              _QuickAction(
                icon: Icons.campaign,
                label: 'Publicar en el tablón',
                onTap: () => context.push('/tablon/create'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final bool highlight;
  _Stat(this.label, this.value, this.icon, {this.highlight = false});
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: stats.map((s) => _StatCard(stat: s)).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color accent = stat.highlight ? scheme.tertiary : scheme.primary;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(stat.icon, color: accent, size: 22),
            Text(
              '${stat.value}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            Text(
              stat.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
