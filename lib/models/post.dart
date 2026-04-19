import 'dart:convert';
import '../utils/date_formatter.dart';

class Post {
  final int id;
  final int userId;
  final String username;
  final String? userAvatar;
  final String? militantBadge;
  final bool isMilitantTechnician;
  final String content;
  final List<String> mediaUrls;
  final String? mediaType; // 'image' ou 'video'
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isOnline;
  final bool isModerator;
  final DateTime createdAt;
  final String? sharedByUsername;
  final DateTime feedDate;

  final String type; // 'post', 'group', 'page'
  final int? groupId;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    this.militantBadge,
    this.isMilitantTechnician = false,
    required this.content,
    required this.mediaUrls,
    this.mediaType,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.isOnline,
    this.isModerator = false,
    required this.createdAt,
    this.sharedByUsername,
    required this.feedDate,
    this.type = 'post',
    this.groupId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<String> mediaList = [];
    if (json['media'] != null) {
      final media = json['media'];
      if (media is String && media.isNotEmpty) {
        if (media.startsWith('[')) {
          try {
            final decoded = jsonDecode(media);
            if (decoded is List) {
              mediaList = decoded.map((e) => e.toString()).toList();
            }
          } catch (e) {
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
      militantBadge: json['militant_badge'],
      isMilitantTechnician: json['is_militant_technician'] == true || json['is_militant_technician'] == 1 || json['is_militant_technician'] == '1',
      content: json['content'] ?? '',
      mediaUrls: mediaList,
      mediaType: json['media_type'],
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      isLiked: json['is_liked'] == 1 || json['is_liked'] == true,
      isOnline: json['is_online'] == 1 || json['is_online'] == true,
      isModerator: json['is_moderator'] == 1 || json['is_moderator'] == true,
      createdAt: DateFormatter.parseApiDate(json['created_at']),
      sharedByUsername: json['shared_by_username'],
      feedDate: DateFormatter.parseApiDate(json['feed_date'] ?? json['created_at']),
      type: json['type'] ?? 'post',
      groupId: json['group_id'],
    );
  }
}
