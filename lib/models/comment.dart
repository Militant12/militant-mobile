class Comment {
  final int id;
  final int postId;
  final int userId;
  final String username;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? 'Utilisateur',
      userAvatar: json['avatar'],
      content: json['content'] ?? '',
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()).replaceAll(' ', 'T'),
      ),
    );
  }
}
