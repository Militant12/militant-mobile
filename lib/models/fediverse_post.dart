import '../utils/date_formatter.dart';

class FediversePost {
  final int id;
  final String remotePostId;
  final String originalUrl;
  final String actorUrl;
  final String username;
  final String? displayName;
  final String? domain;
  final String? handle;
  final String? avatar;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final String? thumbnailUrl;
  final String? profileUrl;
  final DateTime publishedAt;

  const FediversePost({
    required this.id,
    required this.remotePostId,
    required this.originalUrl,
    required this.actorUrl,
    required this.username,
    this.displayName,
    this.domain,
    this.handle,
    this.avatar,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.thumbnailUrl,
    this.profileUrl,
    required this.publishedAt,
  });

  bool get isVideo => (mediaType ?? '').toLowerCase() == 'video';

  factory FediversePost.fromJson(Map<String, dynamic> json) {
    final remotePostId = (json['remote_post_id'] ?? json['original_url'] ?? '')
        .toString();
    return FediversePost(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      remotePostId: remotePostId,
      originalUrl: (json['original_url'] ?? remotePostId).toString(),
      actorUrl: (json['actor_url'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      domain: json['domain']?.toString(),
      handle: json['handle']?.toString(),
      avatar: json['avatar']?.toString(),
      content: (json['content'] ?? '').toString(),
      mediaUrl: json['media_url']?.toString(),
      mediaType: json['media_type']?.toString(),
      thumbnailUrl: (json['thumbnail_url'] ??
              json['media_thumbnail'] ??
              json['media_thumb'] ??
              json['preview_image'] ??
              json['media_preview'])
          ?.toString(),
      profileUrl: json['profile_url']?.toString(),
      publishedAt: DateFormatter.parseApiDate(
        json['published_at'] ?? json['created_at'],
      ),
    );
  }
}
