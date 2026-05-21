import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/blog_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the list every time this screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(blogPostsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return Scaffold(
        appBar: AppBar(
          title: const Text('Blog del Campus'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: postsAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aún no hay entradas en el blog', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(blogPostsProvider);
              },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: InkWell(
                    onTap: () => context.push('/blog/detail/${post.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: post.imageUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.grey.shade200),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                            if (isAdminOrCoach)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Borrar entrada'),
                                          content: const Text('¿Estás seguro de que quieres eliminar esta entrada del blog?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(blogRepositoryProvider).deletePost(post.id);
                                        ref.invalidate(blogPostsProvider);
                                      }
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Por ${post.authorName ?? 'Coordinación'} • ${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              Text(
                                'Por ${post.authorName ?? "Entrenador"} - ${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdminOrCoach ? FloatingActionButton.extended(
        onPressed: () => context.push('/blog/add'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Escribir en el Blog'),
      ) : null,
    );
  }
}
