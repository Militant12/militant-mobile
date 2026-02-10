class User {
  final int id;
  final String username;
  final String? email;
  final String? avatar;
  final String? banner;
  final String? bio;
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
