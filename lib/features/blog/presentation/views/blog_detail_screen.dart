import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
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
                Stack(
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
                              onTap: () => _openViewer(
                                context,
                                allImages,
                                allImages.indexOf(imgUrl),
                              ),
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      CloudinaryService.optimizedUrl(imgUrl),
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
                    if (allImages.length > 1)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                _openGrid(context, allImages),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.grid_view,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${allImages.length} fotos',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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

void _openViewer(BuildContext context, List<String> images, int initialIndex) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullScreenGalleryViewer(
        images: images,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
      ),
    ),
  );
}

void _openGrid(BuildContext context, List<String> images) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black87,
    builder: (sheetCtx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetCtx).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'Fotos (${images.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: images.length,
                itemBuilder: (ctx, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _openViewer(context, images, index);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: CloudinaryService.optimizedUrl(
                          images[index],
                          width: 400,
                        ),
                        fit: BoxFit.cover,
                        placeholder: (c, u) =>
                            Container(color: Colors.grey.shade800),
                        errorWidget: (c, u, e) =>
                            const Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FullScreenGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGalleryViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGalleryViewer> createState() =>
      _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<_FullScreenGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    final url = CloudinaryService.downloadUrl(widget.images[_currentIndex]);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar la foto')),
      );
    }
  }

  void _openGridFromViewer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (sheetCtx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.75,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: widget.images.length,
            itemBuilder: (ctx, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pageController.jumpToPage(index);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: CloudinaryService.optimizedUrl(
                      widget.images[index],
                      width: 400,
                    ),
                    fit: BoxFit.cover,
                    placeholder: (c, u) =>
                        Container(color: Colors.grey.shade800),
                    errorWidget: (c, u, e) =>
                        const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar foto',
            onPressed: _downloadCurrent,
          ),
          if (widget.images.length > 1)
            IconButton(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Ver todas las fotos',
              onPressed: _openGridFromViewer,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: CachedNetworkImage(
                  imageUrl: CloudinaryService.optimizedUrl(
                    widget.images[index],
                    width: 1600,
                  ),
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
