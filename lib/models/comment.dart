class Comment {
  final int id;
  final int postId;
  final int userId;
  final String username;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;
  final int? parentId;
  final List<Comment> replies;
  final int reactionsCount;
  final bool hasReacted;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.replies = const [],
    this.reactionsCount = 0,
    this.hasReacted = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      try {
        if (dateValue is String) {
          // Remplacer l'espace par T pour le format ISO
          final dateStr = dateValue.replaceAll(' ', 'T');
          return DateTime.parse(dateStr);
        }
        return DateTime.now();
      } catch (e) {
        print('Error parsing date: $dateValue - $e');
        return DateTime.now();
      }
    }

    return Comment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? 'Utilisateur',
      userAvatar: json['avatar'],
      content: json['content'] ?? '',
      createdAt: parseDate(json['created_at']),
      parentId: json['parent_id'],
      replies: (json['replies'] as List?)
          ?.map((r) => Comment.fromJson(r))
          .toList() ?? [],
      reactionsCount: json['reactions_count'] ?? 0,
      hasReacted: json['has_reacted'] ?? false,
    );
  }
}
