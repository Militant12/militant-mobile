import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final TextAlign? textAlign;
  final Function(List<String>)? onLinksDetected;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.linkColor,
    this.textAlign,
    this.onLinksDetected,
  });

  @override
  Widget build(BuildContext context) {
    final defaultLinkColor = linkColor ?? const Color(0xFFBE1E1E);

    // Extraire les URLs pour les cartes embed
    final urls = _extractUrls(text);
    if (urls.isNotEmpty && onLinksDetected != null) {
      // Notifier le parent des URLs trouvées
      onLinksDetected!(urls);
    }

    final spans = _buildTextSpans(text, style, defaultLinkColor);

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign ?? TextAlign.start,
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
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      // Ajouter le lien
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style:
              baseStyle?.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
              ) ??
              TextStyle(color: linkColor, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
        ),
      );

      currentIndex = match.end;
    }

    // Ajouter le texte restant
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
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
      debugPrint('Erreur ouverture URL: $e');
    }
  }
}

class LinkPreviewCard extends StatefulWidget {
  final String url;

  const LinkPreviewCard({super.key, required this.url});

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  // bool _isLoading = true; // Removed unused field
  String? _title;
  String? _description;
  String? _imageUrl;
  String? _platform;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    // 1. Détection de plateforme connue (AI & Réseaux sociaux)
    String normalizedUrl = widget.url;
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    _platform = _detectPlatform(normalizedUrl);

    try {
      // 2. Essayer de récupérer les métadonnées OpenGraph
      final response = await http
          .get(Uri.parse(normalizedUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = response.body;

        // Regex simples pour OG tags (évite d'ajouter un parseur HTML lourd)
        final titleReg = RegExp(
          r'<meta\s+(?:property|name)=["'
          "'"
          r']og:title["'
          "'"
          r']\s+content=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
        );
        final descReg = RegExp(
          r'<meta\s+(?:property|name)=["'
          "'"
          r']og:description["'
          "'"
          r']\s+content=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
        );
        final imgReg = RegExp(
          r'<meta\s+(?:property|name)=["'
          "'"
          r']og:image["'
          "'"
          r']\s+content=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
        );
        final titleTagReg = RegExp(
          r'<title>(.*?)</title>',
          caseSensitive: false,
        );

        if (mounted) {
          setState(() {
            _title =
                titleReg.firstMatch(body)?.group(1) ??
                titleTagReg.firstMatch(body)?.group(1);
            _description = descReg.firstMatch(body)?.group(1);
            _imageUrl = imgReg.firstMatch(body)?.group(1);
          });
        }
      }
    } catch (e) {
      debugPrint('LinkPreviewCard error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si c'est une plateforme connue ou qu'on a trouvé des infos, on affiche
    if (_platform == null && _title == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: InkWell(
        onTap: () => _launchUrl(widget.url),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de preview (si disponible)
            if (_imageUrl != null && _imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  _imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Icône de la plateforme ou favicon générique
                  if (_platform != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getPlatformColor(_platform!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getPlatformIcon(_platform!),
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.link,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                  const SizedBox(width: 12),

                  // Infos texte
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_title != null)
                          Text(
                            _title!,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (_platform != null)
                          Text(
                            _getPlatformName(_platform!),
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                        const SizedBox(height: 4),

                        if (_description != null)
                          Text(
                            _description!,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            _shortenUrl(widget.url),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();

    // AI Networks
    if (lowerUrl.contains('openai.com') || lowerUrl.contains('chatgpt.com')) {
      return 'openai';
    } else if (lowerUrl.contains('anthropic.com') ||
        lowerUrl.contains('claude.ai')) {
      return 'anthropic';
    } else if (lowerUrl.contains('huggingface.co')) {
      return 'huggingface';
    } else if (lowerUrl.contains('perplexity.ai')) {
      return 'perplexity';
    } else if (lowerUrl.contains('midjourney.com')) {
      return 'midjourney';
    } else if (lowerUrl.contains('stability.ai')) {
      return 'stability';
    }

    // Social Networks
    if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      return 'twitter';
    } else if (lowerUrl.contains('facebook.com') ||
        lowerUrl.contains('fb.com')) {
      return 'facebook';
    } else if (lowerUrl.contains('instagram.com')) {
      return 'instagram';
    } else if (lowerUrl.contains('tiktok.com')) {
      return 'tiktok';
    } else if (lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be')) {
      return 'youtube';
    } else if (lowerUrl.contains('mastodon') || lowerUrl.contains('/@')) {
      return 'mastodon';
    } else if (lowerUrl.contains('github.com')) {
      return 'github';
    } else if (lowerUrl.contains('linkedin.com')) {
      return 'linkedin';
    } else if (lowerUrl.contains('reddit.com')) {
      return 'reddit';
    }

    return null;
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'openai':
        return const Color(0xFF10A37F);
      case 'anthropic':
        return const Color(0xFFD97757);
      case 'huggingface':
        return const Color(0xFFFFD21E);
      case 'perplexity':
        return const Color(0xFF22B8CF);
      case 'midjourney':
        return const Color(
          0xFFFFFFFF,
        ); // White/Black logic handled by icon usually
      case 'stability':
        return const Color(0xFF000000);

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
      case 'linkedin':
        return const Color(0xFF0077B5);
      case 'reddit':
        return const Color(0xFFFF4500);
      default:
        return const Color(0xFF888888);
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'openai':
      case 'anthropic':
      case 'perplexity':
        return Icons.smart_toy; // AI icon
      case 'huggingface':
        return Icons.emoji_emotions;

      case 'twitter':
      case 'mastodon':
        return Icons.chat_bubble_outline;
      case 'facebook':
      case 'linkedin':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'github':
        return Icons.code;
      case 'reddit':
        return Icons.article;
      default:
        return Icons.link;
    }
  }

  String _getPlatformName(String platform) {
    switch (platform) {
      case 'openai':
        return 'OpenAI / ChatGPT';
      case 'anthropic':
        return 'Anthropic / Claude';
      case 'huggingface':
        return 'Hugging Face';
      case 'perplexity':
        return 'Perplexity';
      case 'midjourney':
        return 'Midjourney';

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
      debugPrint('Erreur ouverture URL: $e');
    }
  }
}
