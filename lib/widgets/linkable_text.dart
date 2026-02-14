import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final Function(String)? onLinkDetected;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.linkColor,
    this.onLinkDetected,
  });

  @override
  Widget build(BuildContext context) {
    final defaultLinkColor = linkColor ?? const Color(0xFFBE1E1E);
    
    // Extraire les URLs pour les cartes embed
    final urls = _extractUrls(text);
    if (urls.isNotEmpty && onLinkDetected != null) {
      // Notifier le parent des URLs trouvées
      for (final url in urls) {
        onLinkDetected!(url);
      }
    }
    
    final spans = _buildTextSpans(text, style, defaultLinkColor);

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+',
      caseSensitive: false,
    );
    
    return urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<TextSpan> _buildTextSpans(
    String text,
    TextStyle? baseStyle,
    Color linkColor,
  ) {
    final List<TextSpan> spans = [];
    
    // Regex pour détecter les URLs
    final urlPattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+',
      caseSensitive: false,
    );

    int currentIndex = 0;
    final matches = urlPattern.allMatches(text);

    for (final match in matches) {
      // Ajouter le texte avant le lien
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }

      // Ajouter le lien
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: baseStyle?.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
        ) ?? TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchUrl(url),
      ));

      currentIndex = match.end;
    }

    // Ajouter le texte restant
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
    }

    // Si aucun lien trouvé, retourner le texte complet
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }

  Future<void> _launchUrl(String urlString) async {
    // Ajouter https:// si nécessaire
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }

    final url = Uri.parse(urlString);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Erreur ouverture URL: $e');
    }
  }
}

class LinkPreviewCard extends StatelessWidget {
  final String url;

  const LinkPreviewCard({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final platform = _detectPlatform(url);
    
    if (platform == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icône de la plateforme
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getPlatformColor(platform),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPlatformIcon(platform),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPlatformName(platform),
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _shortenUrl(url),
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: theme.iconTheme.color?.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();
    
    if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      return 'twitter';
    } else if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.com')) {
      return 'facebook';
    } else if (lowerUrl.contains('instagram.com')) {
      return 'instagram';
    } else if (lowerUrl.contains('tiktok.com')) {
      return 'tiktok';
    } else if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return 'youtube';
    } else if (lowerUrl.contains('mastodon') || lowerUrl.contains('/@')) {
      return 'mastodon';
    } else if (lowerUrl.contains('github.com')) {
      return 'github';
    }
    
    return null;
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'twitter':
        return const Color(0xFF1DA1F2);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'mastodon':
        return const Color(0xFF6364FF);
      case 'github':
        return const Color(0xFF181717);
      default:
        return const Color(0xFF888888);
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'twitter':
      case 'mastodon':
        return Icons.chat_bubble_outline;
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'github':
        return Icons.code;
      default:
        return Icons.link;
    }
  }

  String _getPlatformName(String platform) {
    switch (platform) {
      case 'twitter':
        return 'X (Twitter)';
      case 'facebook':
        return 'Facebook';
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'youtube':
        return 'YouTube';
      case 'mastodon':
        return 'Mastodon';
      case 'github':
        return 'GitHub';
      default:
        return 'Lien';
    }
  }

  String _shortenUrl(String url) {
    if (url.length > 50) {
      return '${url.substring(0, 47)}...';
    }
    return url;
  }

  Future<void> _launchUrl(String urlString) async {
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }

    final url = Uri.parse(urlString);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Erreur ouverture URL: $e');
    }
  }
}
