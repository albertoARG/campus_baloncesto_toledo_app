class BlogPostModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final DateTime createdAt;
  final String? authorName;

  BlogPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.createdAt,
    this.authorName,
  });

  factory BlogPostModel.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['users'] != null) {
      name = '${json['users']['nombre'] ?? ''} ${json['users']['apellidos'] ?? ''}'.trim();
    }
    
    return BlogPostModel(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      authorId: json['author_id'],
      createdAt: DateTime.parse(json['created_at']),
      authorName: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'content': content,
      'author_id': authorId,
    };
  }
}
