class User {
  final int id;
  final String username;
  final String? email;
  final String? avatar;
  final String? banner;
  final String? bio;
  final String? cause;
  final String? militantBadge;
  final String? website;
  final String? twitter;
  final String? instagram;
  final String? mastodon;
  final String? facebook;
  final String? tiktok;
  final String? bluesky;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    this.email,
    this.avatar,
    this.banner,
    this.bio,
    this.cause,
    this.militantBadge,
    this.website,
    this.twitter,
    this.instagram,
    this.mastodon,
    this.facebook,
    this.tiktok,
    this.bluesky,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? 'Utilisateur',
      email: json['email'],
      avatar: json['avatar'],
      banner: json['banner'],
      bio: json['bio'],
      cause: json['cause'],
      militantBadge: json['militant_badge'],
      website: json['website'],
      twitter: json['twitter'],
      instagram: json['instagram'],
      mastodon: json['mastodon'],
      facebook: json['facebook'],
      tiktok: json['tiktok'],
      bluesky: json['bluesky'],
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] == 1 || json['is_following'] == true,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()).replaceAll(
          ' ',
          'T',
        ),
      ),
    );
  }
}
