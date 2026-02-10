import 'dart:convert';

class Post {
  final int id;
  final int userId;
  final String username;
  final String? userAvatar;
  final String content;
  final List<String> mediaUrls;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.content,
    required this.mediaUrls,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // Gérer les différents formats de média
    List<String> mediaList = [];
    if (json['media'] != null) {
      final media = json['media'];
      if (media is String && media.isNotEmpty) {
        // Si c'est une chaîne, vérifier si c'est du JSON
        if (media.startsWith('[')) {
          try {
            final decoded = jsonDecode(media);
            if (decoded is List) {
              mediaList = decoded.map((e) => e.toString()).toList();
            }
          } catch (e) {
            // Si le décodage échoue, traiter comme une seule URL
            mediaList = [media];
          }
        } else {
          mediaList = [media];
        }
      } else if (media is List) {
        mediaList = media.map((e) => e.toString()).toList();
      }
    }

    return Post(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? 'Utilisateur',
      userAvatar: json['avatar'],
      content: json['content'] ?? '',
      mediaUrls: mediaList,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      isLiked: json['is_liked'] == 1 || json['is_liked'] == true,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()).replaceAll(
          ' ',
          'T',
        ),
      ),
    );
  }
}
