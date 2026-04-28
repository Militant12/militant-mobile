import '../utils/date_formatter.dart';

class FeatureSuggestionComment {
  final int id;
  final int suggestionId;
  final int userId;
  final String username;
  final String? avatar;
  final String content;
  final DateTime createdAt;

  const FeatureSuggestionComment({
    required this.id,
    required this.suggestionId,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.content,
    required this.createdAt,
  });

  factory FeatureSuggestionComment.fromJson(Map<String, dynamic> json) {
    return FeatureSuggestionComment(
      id: int.tryParse(json['id'].toString()) ?? 0,
      suggestionId: int.tryParse(json['suggestion_id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      username: json['username']?.toString() ?? 'Utilisateur',
      avatar: json['avatar']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: DateFormatter.parseApiDate(json['created_at']),
    );
  }
}

class FeatureSuggestion {
  final int id;
  final int userId;
  final String username;
  final String? avatar;
  final String title;
  final String description;
  final String status;
  final String? adminResponse;
  final int votesUp;
  final int votesDown;
  final int score;
  final int commentCount;
  final int? myVote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeatureSuggestion({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.title,
    required this.description,
    required this.status,
    required this.adminResponse,
    required this.votesUp,
    required this.votesDown,
    required this.score,
    required this.commentCount,
    required this.myVote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeatureSuggestion.fromJson(Map<String, dynamic> json) {
    final votesUp = int.tryParse(json['votes_up'].toString()) ?? 0;
    final votesDown = int.tryParse(json['votes_down'].toString()) ?? 0;
    return FeatureSuggestion(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      username: json['username']?.toString() ?? 'Utilisateur',
      avatar: json['avatar']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      adminResponse: json['admin_response']?.toString(),
      votesUp: votesUp,
      votesDown: votesDown,
      score: int.tryParse(json['score'].toString()) ?? (votesUp - votesDown),
      commentCount: int.tryParse(json['comment_count'].toString()) ?? 0,
      myVote: json['my_vote'] == null
          ? null
          : int.tryParse(json['my_vote'].toString()),
      createdAt: DateFormatter.parseApiDate(json['created_at']),
      updatedAt: DateFormatter.parseApiDate(
        json['updated_at'] ?? json['created_at'],
      ),
    );
  }
}
