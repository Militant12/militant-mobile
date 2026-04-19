import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/fediverse_post.dart';
import '../services/language_service.dart';
import '../utils/date_formatter.dart';
import '../utils/fediverse_text.dart';
import 'linkable_text.dart';
import 'video_player_widget.dart';

class FediversePostCard extends StatelessWidget {
  final FediversePost post;
  final VoidCallback? onProfileTap;

  const FediversePostCard({super.key, required this.post, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = fediverseHtmlToText(post.content);
    final avatarUrl = post.avatar != null && post.avatar!.trim().isNotEmpty
        ? post.avatar
        : null;
    final displayName = (post.displayName?.trim().isNotEmpty ?? false)
        ? post.displayName!.trim()
        : post.username;
    final lang = LanguageService.instance;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Padding(
                              padding: const EdgeInsets.all(4),
                              child: SvgPicture.asset('assets/logo.svg'),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post.handle ?? '@${post.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.formatRelative(post.publishedAt),
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinkableText(
                text: content,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  height: 1.45,
                ),
              ),
            ],
            if (post.mediaUrl != null && post.mediaUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              if (post.isVideo)
                VideoPlayerWidget(videoUrl: post.mediaUrl!)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    post.mediaUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onProfileTap != null)
                  OutlinedButton.icon(
                    onPressed: onProfileTap,
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: Text(lang.translate('profile')),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _openExternalUrl(post.originalUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(lang.translate('open')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(String? rawUrl) async {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return;
  }

  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) {
    return;
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
