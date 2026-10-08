import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'common/app_avatar.dart';

String? resolveMentionAvatarUrl(Map<String, dynamic> user, ApiService api) {
  for (final key in const [
    'avatar',
    'user_avatar',
    'profile_picture',
    'image',
  ]) {
    final value = user[key]?.toString().trim();
    if (value == null || value.isEmpty) continue;
    final resolved = api.getImageUrl(value);
    if (resolved != null && resolved.isNotEmpty) return resolved;
  }
  return null;
}

class MentionUserAvatar extends StatelessWidget {
  final Map<String, dynamic> user;
  final ApiService api;
  final double radius;

  const MentionUserAvatar({
    super.key,
    required this.user,
    required this.api,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      url: resolveMentionAvatarUrl(user, api),
      semanticLabel: user['username']?.toString(),
      radius: radius,
    );
  }
}
