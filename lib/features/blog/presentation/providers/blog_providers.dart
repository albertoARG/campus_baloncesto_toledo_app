import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/blog_repository.dart';
import '../../data/models/blog_post_model.dart';

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  return BlogRepository(ref.watch(supabaseClientProvider));
});

final blogPostsProvider = FutureProvider<List<BlogPostModel>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  return repo.getPosts();
});
