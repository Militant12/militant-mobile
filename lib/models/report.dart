import '../utils/date_formatter.dart';

class Report {
  final int id;
  final String reason;
  final String? description;
  final int? postId;
  final int? userId;
  final String? postContent;
  final String? reportedUsername;
  final String reporterUsername;
  final int voteCount;
  final String? myVote;
  final String status;
  final DateTime createdAt;

  Report({
    required this.id,
    required this.reason,
    this.description,
    this.postId,
    this.userId,
    this.postContent,
    this.reportedUsername,
    required this.reporterUsername,
    required this.voteCount,
    this.myVote,
    required this.status,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] ?? 0,
      reason: json['reason'] ?? '',
      description: json['description'],
      postId: json['post_id'],
      userId: json['user_id'],
      postContent: json['post_content'],
      reportedUsername: json['reported_username'],
      reporterUsername: json['reporter_username'] ?? 'Utilisateur',
      voteCount: json['vote_count'] ?? 0,
      myVote: json['my_vote'],
      status: json['status'] ?? 'pending',
      createdAt: DateFormatter.parseApiDate(json['created_at']),
    );
  }
}

class ModeratorCandidate {
  final int userId;
  final String username;
  final String? avatar;
  final String? motivation;
  final int votesFor;
  final int votesAgainst;
  final String? myVote;
  final DateTime createdAt;

  ModeratorCandidate({
    required this.userId,
    required this.username,
    this.avatar,
    this.motivation,
    required this.votesFor,
    required this.votesAgainst,
    this.myVote,
    required this.createdAt,
  });

  factory ModeratorCandidate.fromJson(Map<String, dynamic> json) {
    return ModeratorCandidate(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? 'Utilisateur',
      avatar: json['avatar'],
      motivation: json['motivation'],
      votesFor: json['votes_for'] ?? 0,
      votesAgainst: json['votes_against'] ?? 0,
      myVote: json['my_vote'],
      createdAt: DateFormatter.parseApiDate(json['created_at']),
    );
  }
}
