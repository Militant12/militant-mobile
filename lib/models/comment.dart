import '../utils/date_formatter.dart';

class Comment {
  final int id;
  final int postId;
  final int userId;
  final String username;
  final String? userAvatar;
  final String? militantBadge;
  final bool isMilitantTechnician;
  final bool isModerator;
  final String content;
  final DateTime createdAt;
  final int? parentId;
  final List<Comment> replies;
  final int reactionsCount;
  final bool hasReacted;
  bool isTranslated = false;
  String? translatedContent;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.userAvatar,
    this.militantBadge,
    this.isMilitantTechnician = false,
    this.isModerator = false,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.replies = const [],
    this.reactionsCount = 0,
    this.hasReacted = false,
    this.isTranslated = false,
    this.translatedContent,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? 'Utilisateur',
      userAvatar: json['avatar'],
      militantBadge: json['militant_badge'],
      isMilitantTechnician: json['is_militant_technician'] == true || json['is_militant_technician'] == 1 || json['is_militant_technician'] == '1',
      isModerator: json['is_moderator'] == true || json['is_moderator'] == 1 || json['is_moderator'] == '1',
      content: json['content'] ?? '',
      createdAt: DateFormatter.parseApiDate(json['created_at']),
      parentId: json['parent_id'],
      replies:
          (json['replies'] as List?)
              ?.map((r) => Comment.fromJson(r))
              .toList() ??
          [],
      reactionsCount: json['reactions_count'] ?? 0,
      hasReacted: (json['has_reacted'] is int)
          ? (json['has_reacted'] as int) > 0
          : (json['has_reacted'] ?? false),
    );
  }
}
