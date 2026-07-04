import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_baloncesto_app/core/services/cloudinary_service.dart';
import 'package:campus_baloncesto_app/features/blog/data/models/blog_post_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/blog_providers.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String postId;

  const BlogDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(blogPostsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final String userRole = userProfileAsync.value?.role ?? 'visitante';
    final isAdminOrCoach = userRole == 'admin' || userRole == 'entrenador';

    return postsAsync.when(
      data: (posts) {
        final latestPost = posts.firstWhere(
          (p) => p.id == postId,
          orElse: () => posts
              .first, // Fallback if not found, though realistically it should be
        );

        // La portada (image_url) siempre va primero.
        // La galería (image_urls) se añade después, evitando duplicados.
        final Set<String> seenUrls = {};
        final List<String> allImages = [];
        if (latestPost.imageUrl.isNotEmpty) {
          allImages.add(latestPost.imageUrl);
          seenUrls.add(latestPost.imageUrl);
        }
        if (latestPost.imageUrls != null) {
          for (final url in latestPost.imageUrls!) {
            if (!seenUrls.contains(url)) {
              allImages.add(url);
              seenUrls.add(url);
            }
          }
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(''), // Empty
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(
              color: Colors.white,
              shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
            ),
          ),
          floatingActionButton: isAdminOrCoach
              ? FloatingActionButton(
                  onPressed: () =>
                      context.pushReplacement('/blog/edit/${latestPost.id}'),
                  tooltip: 'Editar Entrada',
                  child: const Icon(Icons.edit),
                )
              : null,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarouselSlider(
                  key: ValueKey(allImages.length),
                  options: CarouselOptions(
                    height: MediaQuery.of(context).size.height * 0.45,
                    viewportFraction: 1.0,
                    enableInfiniteScroll: allImages.length > 1,
                    autoPlay: allImages.length > 1,
                  ),
                  items: allImages.map((imgUrl) {
                    return Builder(
                      builder: (BuildContext context) {
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) =>
                                  _FullScreenImageViewer(imageUrl: imgUrl),
                            ),
                          ),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: CloudinaryService.optimizedUrl(imgUrl),
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestPost.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            latestPost.authorName ?? 'Coordinación',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.date_range,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${latestPost.createdAt.day}/${latestPost.createdAt.month}/${latestPost.createdAt.year}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        latestPost.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 17,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: CachedNetworkImage(
              imageUrl: CloudinaryService.optimizedUrl(imageUrl, width: 1600),
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
