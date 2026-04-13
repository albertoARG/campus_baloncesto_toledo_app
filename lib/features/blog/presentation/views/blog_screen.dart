import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/blog_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class BlogScreen extends ConsumerWidget {
  const BlogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(blogPostsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Tablón de Anuncios'),
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No hay avisos por el momento', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          if (isAdminOrCoach)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Borrar aviso'),
                                    content: const Text('¿Estás seguro?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar', style: TextStyle(color: Colors.red))),
                                    ]
                                  )
                                );
                                if (confirm == true) {
                                  await ref.read(blogRepositoryProvider).deletePost(post.id);
                                  ref.invalidate(blogPostsProvider);
                                }
                              },
                            )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(post.authorName ?? 'Coordinación', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const Spacer(),
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${post.createdAt.day}/${post.createdAt.month} ${post.createdAt.hour.toString().padLeft(2,'0')}:${post.createdAt.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdminOrCoach ? FloatingActionButton.extended(
        onPressed: () => context.push('/blog/create'),
        icon: const Icon(Icons.add_comment),
        label: const Text('Nuevo Aviso'),
      ) : null,
    );
  }
}
