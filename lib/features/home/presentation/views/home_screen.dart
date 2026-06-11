import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../tablon/presentation/providers/tablon_providers.dart';
import '../../../blog/presentation/providers/blog_providers.dart';
import '../../../../core/services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _webNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh the banner data every time we open/return to home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(tablonPostsProvider);
    });

    // Listen for incoming messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        final title = message.notification?.title ?? 'Nuevo Aviso';
        final body = message.notification?.body ?? '';
        // Refrescar datos del tablón automáticamente
        ref.invalidate(tablonPostsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VER',
              onPressed: () {
                context.push('/tablon');
              },
            ),
          ),
        );
      }
    });

    // On Web: check if already registered, otherwise show prompt dialog
    if (kIsWeb) {
      _checkAndPromptWebNotifications();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Cuando la app vuelve del segundo plano (ej: al pulsar notificación), refrescar datos
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(tablonPostsProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAndPromptWebNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRegistered =
        prefs.getBool('web_notifications_registered') ?? false;

    if (alreadyRegistered) {
      if (mounted) setState(() => _webNotificationsEnabled = true);
      return;
    }

    // Small delay to let the UI render first
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Activar Notificaciones')),
          ],
        ),
        content: const Text(
          '¿Quieres recibir notificaciones de los avisos del campus directamente en tu dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Activar'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await _registerWebNotifications();
    }
  }

  Future<void> _registerWebNotifications() async {
    void showMsg(String msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
        );
      }
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        showMsg(
          '❌ Permisos denegados. Actívalos en los ajustes del navegador.',
        );
        return;
      }

      final token = await messaging.getToken(
        vapidKey:
            'BLCT2TkMoEbywUENHTyAKM0UFMAnl5Jszp66Fh7VJEj7Kcy7NLdm0JepIKJWiEArcMogERlLhp0p6NLKcg6K92I',
      );

      if (token == null) {
        showMsg('❌ No se pudo obtener el token. Intenta recargar la web.');
        return;
      }

      await Supabase.instance.client.from('fcm_tokens').upsert({
        'token': token,
        'platform': 'web',
      }, onConflict: 'token');

      // Remember for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('web_notifications_registered', true);

      if (mounted) setState(() => _webNotificationsEnabled = true);
      showMsg('✅ ¡Notificaciones activadas correctamente!');
    } catch (e) {
      showMsg('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final session = Supabase.instance.client.auth.currentSession;
    final String role = session == null
        ? 'visitante'
        : (userProfileAsync.value?.role ?? 'visitante');
    final bool canManageScores = role == 'admin' || role == 'entrenador';
    final bool isAdmin = role == 'admin';
    final String userName = session == null
        ? 'Invitado'
        : (userProfileAsync.value?.nombre ?? '');

    // Subscribe/unsubscribe from staff notifications based on role
    if (session != null && userProfileAsync.value != null) {
      final notifService = ref.read(notificationServiceProvider);
      if (canManageScores) {
        notifService.subscribeToStaffTopic();
      } else {
        notifService.unsubscribeFromStaffTopic();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Toledo'),
        centerTitle: false,
        actions: [
          // Show bell only on Web and only if not yet registered
          if (kIsWeb && !_webNotificationsEnabled)
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Activar Notificaciones',
              onPressed: () => _registerWebNotifications(),
            ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Mi Perfil',
            onPressed: () => session != null
                ? context.push('/profile')
                : context.push('/login'),
          ),
        ],
      ),
      drawer: _AppDrawer(
        role: role,
        userName: userName,
        isAdmin: isAdmin,
        canManageScores: canManageScores,
      ),
      body: _HomeBody(
        canManageScores: canManageScores,
        isAdmin: isAdmin,
        session: session,
        role: role,
      ),
    );
  }
}

// ─── Drawer lateral ─────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  final String role;
  final String userName;
  final bool isAdmin;
  final bool canManageScores;
  const _AppDrawer({
    required this.role,
    required this.userName,
    required this.isAdmin,
    required this.canManageScores,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isLoggedIn =
        Supabase.instance.client.auth.currentSession != null;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userName.isNotEmpty ? userName : 'Invitado',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ─── Sección: Todos ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'GENERAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _DrawerItem(
            icon: Icons.leaderboard_outlined,
            label: 'Clasificación',
            onTap: () {
              Navigator.pop(context);
              context.push('/standings');
            },
          ),
          _DrawerItem(
            icon: Icons.photo_library_outlined,
            label: 'Blog',
            onTap: () {
              Navigator.pop(context);
              context.push('/blog');
            },
          ),
          _DrawerItem(
            icon: Icons.sports_tennis,
            label: 'Competiciones Siesta',
            onTap: () {
              Navigator.pop(context);
              context.push('/siesta');
            },
          ),
          _DrawerItem(
            icon: Icons.nightlight_round,
            label: 'Veladas',
            onTap: () {
              Navigator.pop(context);
              context.push('/veladas');
            },
          ),
          _DrawerItem(
            icon: Icons.forum_outlined,
            label: 'Tablón de Anuncios',
            onTap: () {
              Navigator.pop(context);
              context.push('/tablon');
            },
          ),
          _DrawerItem(
            icon: Icons.person_outline,
            label: 'Mi Perfil',
            onTap: () {
              Navigator.pop(context);
              isLoggedIn ? context.push('/profile') : context.push('/login');
            },
          ),
          _DrawerItem(
            icon: Icons.fitness_center,
            label: 'Entrenamientos',
            onTap: () {
              Navigator.pop(context);
              context.push('/trainings');
            },
          ),
          if (role == 'admin' ||
              role == 'entrenador' ||
              role == 'jugador premium')
            _DrawerItem(
              icon: Icons.bar_chart,
              label: 'Estadísticas Deportivas',
              onTap: () {
                Navigator.pop(context);
                context.push('/stats');
              },
            ),

          // ─── Sección: Solo Staff ────────────────────────────
          if (canManageScores) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'SOLO STAFF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (isAdmin)
              _DrawerItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                iconColor: Theme.of(context).colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin/dashboard');
                },
              ),
            _DrawerItem(
              icon: Icons.sports_score,
              label: 'Puntuar Estación',
              iconColor: Theme.of(context).colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                context.push('/add-score');
              },
            ),
            _DrawerItem(
              icon: Icons.tune,
              label: 'Gestión Competición',
              iconColor: Theme.of(context).colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                context.push('/competitions/manage');
              },
            ),
            _DrawerItem(
              icon: Icons.group,
              label: 'Grupos Competición',
              iconColor: Theme.of(context).colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/groups');
              },
            ),
            _DrawerItem(
              icon: Icons.auto_awesome,
              label: 'Gestión Veladas',
              iconColor: Theme.of(context).colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/veladas');
              },
            ),
            if (isAdmin)
              _DrawerItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Gestionar Usuarios',
                iconColor: Theme.of(context).colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin/users');
                },
              ),
          ],

          // ─── Sección: Sesión ────────────────────────────────
          const Divider(),
          if (isLoggedIn)
            _DrawerItem(
              icon: Icons.logout,
              label: 'Cerrar Sesión',
              iconColor: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text(
                      '¿Estás seguro de que quieres cerrar sesión?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/');
                }
              },
            )
          else
            _DrawerItem(
              icon: Icons.login,
              label: 'Iniciar Sesión',
              onTap: () {
                Navigator.pop(context);
                context.push('/login');
              },
            ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label),
      onTap: onTap,
    );
  }
}

// ─── Cuerpo principal (cuadrícula de accesos) ────────────────────────────────

class _HomeBody extends ConsumerWidget {
  final bool canManageScores;
  final bool isAdmin;
  final dynamic session;
  final String role;

  const _HomeBody({
    required this.canManageScores,
    required this.isAdmin,
    required this.session,
    required this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _buildItems(context);
    final postsAsync = ref.watch(tablonPostsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tablonPostsProvider);
        ref.invalidate(blogPostsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Bienvenido al Campus',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecciona una sección para comenzar',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) return const SizedBox.shrink();
                final latest = posts.first;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: InkWell(
                    onTap: () => context.push('/tablon'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade700,
                            Colors.orange.shade500,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.campaign,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latest.isStaffOnly
                                      ? 'ÚLTIMO AVISO - SOLO STAFF'
                                      : 'ÚLTIMO AVISO',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  latest.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    final isPremium =
        role == 'jugador premium' || role == 'admin' || role == 'entrenador';

    final widgets = <Widget>[
      _ImageNavCard(
        imageUrl: 'assets/images/compet.png',
        title: 'VER COMPETICIONES',
        onTap: () => context.push('/standings'),
        secondaryTitle: canManageScores ? 'AÑADIR PUNTUACIÓN' : null,
        onSecondaryTap: canManageScores
            ? () => context.push('/add-score')
            : null,
      ),
      _ImageNavCard(
        imageUrl: 'assets/images/blog.jpg',
        title: 'BLOG DEL CAMPUS',
        onTap: () => context.push('/blog'),
      ),
      _ImageNavCard(
        imageUrl: 'assets/images/siesta.jpg',
        title: 'COMPES DE SIESTA',
        onTap: () => context.push('/siesta'),
      ),
      _ImageNavCard(
        imageUrl: 'assets/images/veladas.jpg',
        title: 'VELADAS',
        onTap: () => context.push('/veladas'),
      ),
      _ImageNavCard(
        imageUrl: 'assets/images/anuncio.jpg',
        title: 'TABLÓN DE ANUNCIOS',
        onTap: () => context.push('/tablon'),
      ),
      _ImageNavCard(
        imageUrl:
            'https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=800&auto=format&fit=crop',
        title: 'ENTRENAMIENTOS',
        onTap: () => context.push('/trainings'),
      ),
      if (isPremium)
        _ImageNavCard(
          imageUrl:
              'https://images.unsplash.com/photo-1551288049-bebda4e38f71?q=80&w=800&auto=format&fit=crop',
          title: 'ESTADÍSTICAS DEPORTIVAS',
          onTap: () => context.push('/stats'),
        ),
    ];

    if (canManageScores || isAdmin) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(
        const Text(
          'ZONA ADMINISTRACIÓN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));

      if (canManageScores) {
        widgets.add(
          _buildAdminBtn(
            context,
            'Gestión Competición',
            Icons.tune,
            () => context.push('/competitions/manage'),
          ),
        );
        widgets.add(
          _buildAdminBtn(
            context,
            'Grupos Competición',
            Icons.group,
            () => context.push('/admin/groups'),
          ),
        );
        widgets.add(
          _buildAdminBtn(
            context,
            'Gestión Veladas',
            Icons.auto_awesome,
            () => context.push('/admin/veladas'),
          ),
        );
      }
      if (isAdmin) {
        widgets.add(
          _buildAdminBtn(
            context,
            'Gestionar Usuarios',
            Icons.manage_accounts,
            () => context.push('/admin/users'),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildAdminBtn(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}

class _ImageNavCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;
  final String? secondaryTitle;
  final VoidCallback? onSecondaryTap;

  const _ImageNavCard({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.secondaryTitle,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = imageUrl.startsWith('http');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 160,
                child: isNetwork
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          height: 160,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          height: 160,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.primary,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            if (secondaryTitle != null && onSecondaryTap != null) ...[
              Container(height: 1, color: Colors.white24),
              Material(
                color: Theme.of(context).colorScheme.primary,
                child: InkWell(
                  onTap: onSecondaryTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Text(
                      secondaryTitle!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
