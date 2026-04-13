import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/blog_post_model.dart';

class BlogRepository {
  final SupabaseClient _supabaseClient;
  BlogRepository(this._supabaseClient);

  Future<List<BlogPostModel>> getPosts() async {
    final response = await _supabaseClient
        .from('blog_posts')
        .select('*, users(nombre, apellidos)')
        .order('created_at', ascending: false);
        
    return (response as List).map((json) => BlogPostModel.fromJson(json)).toList();
  }

  Future<void> createPost(String title, String content, String authorId) async {
    final data = {
      'title': title,
      'content': content,
      'author_id': authorId,
    };
    await _supabaseClient.from('blog_posts').insert(data);
  }

  Future<void> deletePost(String id) async {
    await _supabaseClient.from('blog_posts').delete().eq('id', id);
  }
}
