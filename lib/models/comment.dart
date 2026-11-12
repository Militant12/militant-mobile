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

  // Modifiés sur place quand on réagit, sans recharger toute la liste.
  int reactionsCount;
  bool hasReacted;

  /// Réaction choisie (`like`, `love`…), seulement pour les pages.
  String? userReaction;

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
    this.userReaction,
    this.isTranslated = false,
    this.translatedContent,
  });

  /// Lit un commentaire de post, de groupe ou de page : les pages renvoient
  /// `user_avatar` et `user_reaction` au lieu de `avatar`.
  factory Comment.fromJson(Map<String, dynamic> json) {
    final userReaction = (json['user_reaction'] ?? '').toString();
    return Comment(
      id: _asInt(json['id']) ?? 0,
      postId: _asInt(json['post_id']) ?? 0,
      userId: _asInt(json['user_id']) ?? 0,
      username: json['username'] ?? 'Utilisateur',
      userAvatar: json['avatar'] ?? json['user_avatar'],
      militantBadge: json['militant_badge'],
      isMilitantTechnician: _asBool(json['is_militant_technician']),
      isModerator: _asBool(json['is_moderator']),
      content: json['content'] ?? '',
      createdAt: DateFormatter.parseApiDate(json['created_at']),
      parentId: _asInt(json['parent_id']),
      replies:
          (json['replies'] as List?)
              ?.map((r) => Comment.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          [],
      reactionsCount: _asInt(json['reactions_count']) ?? 0,
      hasReacted: _asBool(json['has_reacted']) || userReaction.isNotEmpty,
      userReaction: userReaction.isEmpty ? null : userReaction,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final parsed = int.tryParse(value.toString());
    return parsed == 0 ? null : parsed;
  }

  static bool _asBool(dynamic value) =>
      value == true || value == 1 || value == '1';
}
