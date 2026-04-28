import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

    // Regex pour détecter les URLs, les Mentions (@pseudo) et les hashtags
    final combinedPattern = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+)|(@\w+)|(#[A-Za-z0-9_]+)',
      caseSensitive: false,
    );

    int currentIndex = 0;
    final matches = combinedPattern.allMatches(text);

    for (final match in matches) {
      // Ajouter le texte avant le match
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchText = match.group(0)!;
      final isMention = match.group(2) != null;
      final isHashtag = match.group(3) != null;

      if (isMention || isHashtag) {
        // Ajouter la mention ou le hashtag en gras
        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle?.copyWith(
              color: linkColor,
              fontWeight: FontWeight.bold,
            ) ?? TextStyle(color: linkColor, fontWeight: FontWeight.bold),
          ),
        );
      } else {
        // Ajouter le lien
        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle?.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
            ) ?? TextStyle(color: linkColor, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(matchText),
          ),
        );
      }

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
  String? _faviconUrl;
  String? _platform;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  String _getNormalizedUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  Future<void> _fetchMetadata() async {
    // 1. Détection de plateforme connue (AI & Réseaux sociaux)
    final normalizedUrl = _getNormalizedUrl(widget.url);
    final uri = Uri.parse(normalizedUrl);

    if (mounted) {
      setState(() {
        _faviconUrl =
            'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128';
      });
    }

    _platform = _detectPlatform(normalizedUrl);

    try {
      // 2. Essayer de récupérer les métadonnées OpenGraph
      final response = await http
          .get(Uri.parse(normalizedUrl), headers: {
            'User-Agent':
                'Mozilla/5.0 (Compatible; MilitantBot/1.0; +https://militant.sh)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
            'Accept-Charset': 'utf-8',
          })
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Détecter l'encodage à partir du header Content-Type
        String encoding = 'utf-8';
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.toLowerCase().contains('charset=')) {
          final match = RegExp(r'charset=([^;]+)').firstMatch(contentType);
          if (match != null) {
            encoding = match.group(1)!.trim().toLowerCase();
          }
        }

        String body;
        try {
          if (encoding == 'iso-8859-1' || encoding == 'latin1') {
            body = latin1.decode(response.bodyBytes);
          } else {
            body = utf8.decode(response.bodyBytes, allowMalformed: true);
          }
        } catch (_) {
          body = response.body; // Fallback par défaut
        }

        // 3. Chercher un favicon dans le HTML si google service échoue ou en complément
        final iconReg = RegExp(
          r'<link[^>]+(?:rel=["'
          "'"
          r'](?:shortcut )?icon["'
          "'"
          r'])[^>]+href=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
        );
        final foundIcon = iconReg.firstMatch(body)?.group(1);
        if (foundIcon != null && mounted) {
          String absoluteIcon = foundIcon;
          if (!foundIcon.startsWith('http')) {
            if (foundIcon.startsWith('//')) {
              absoluteIcon = 'https:$foundIcon';
            } else if (foundIcon.startsWith('/')) {
              absoluteIcon = '${uri.scheme}://${uri.host}$foundIcon';
            } else {
              absoluteIcon = '${uri.scheme}://${uri.host}/$foundIcon';
            }
          }
          setState(() {
            _faviconUrl = absoluteIcon;
          });
        }

        // Regex robustes pour OG tags (gère double et simple quotes, et espaces)
        final titleReg = RegExp(
          r'<meta[^>]+(?:property|name)=["'
          "'"
          r']og:title["'
          "'"
          r'][^>]+content=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
          dotAll: true,
        );
        final descReg = RegExp(
          r'<meta[^>]+(?:property|name)=["'
          "'"
          r']og:description["'
          "'"
          r'][^>]+content=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
          dotAll: true,
        );
        final imgReg = RegExp(
          r'<meta[^>]+(?:property|name)=["'
          "'"
          r']og:image["'
          "'"
          r'][^>]+content=["'
          "'"
          r'](.*?)["'
          "'"
          r']',
          caseSensitive: false,
          dotAll: true,
        );
        final titleTagReg = RegExp(
          r'<title>(.*?)</title>',
          caseSensitive: false,
          dotAll: true,
        );

        if (mounted) {
          setState(() {
            _title = _decodeHtml(
              titleReg.firstMatch(body)?.group(1) ??
                  titleTagReg.firstMatch(body)?.group(1),
            );
            _description = _decodeHtml(descReg.firstMatch(body)?.group(1));
            _imageUrl = imgReg.firstMatch(body)?.group(1);

            // Si plateforme non détectée, on essaie via le titre
            if (_platform == null && _title != null) {
              final lowerTitle = _title!.toLowerCase();
              if (lowerTitle.contains('twitter') || lowerTitle.contains(' x ')) {
                _platform = 'twitter';
              } else if (lowerTitle.contains('facebook')) {
                _platform = 'facebook';
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('LinkPreviewCard error: $e');
    }
  }

  // Décodage basique des entités HTML pour éviter les &amp;, &quot;, etc.
  String? _decodeHtml(String? input) {
    if (input == null) return null;
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        // Décodage des entités numériques type &#39; ou &#039; ou &#x27;
        .replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (match) {
          final code = match.group(1)!;
          try {
            if (code.startsWith('x')) {
              return String.fromCharCode(
                int.parse(code.substring(1), radix: 16),
              );
            } else {
              return String.fromCharCode(int.parse(code));
            }
          } catch (e) {
            return match.group(0)!;
          }
        })
        .trim();
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _platform != null 
                          ? _getPlatformColor(_platform)
                          : isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: _platform == null ? Border.all(color: isDark ? Colors.white10 : Colors.black12) : null,
                    ),
                    child: Center(
                      child: _platform != null
                          ? FaIcon(
                            _getPlatformIcon(_platform),
                            color:
                                _platform == 'midjourney' ||
                                        _platform == 'huggingface'
                                    ? Colors.black
                                    : Colors.white,
                            size: 18,
                          )
                          : _faviconUrl != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              _faviconUrl!,
                              width: 24,
                              height: 24,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      Icon(
                                        Icons.link,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        size: 20,
                                      ),
                            ),
                          )
                          : Icon(
                            Icons.link,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 20,
                          ),
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

  Color _getPlatformColor(String? platform) {
    if (platform == null) return const Color(0xFF888888);
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
        return const Color(0xFF000000); // X style
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
        return const Color(0xFFBE1E1E); // Couleur thème Militant par défaut
    }
  }

  IconData _getPlatformIcon(String? platform) {
    if (platform == null) return FontAwesomeIcons.link;
    switch (platform) {
      case 'openai':
        return FontAwesomeIcons.bolt;
      case 'anthropic':
        return FontAwesomeIcons.feather;
      case 'huggingface':
        return FontAwesomeIcons.faceSmile;
      case 'perplexity':
        return FontAwesomeIcons.magnifyingGlass;
      case 'midjourney':
        return FontAwesomeIcons.paintbrush;

      case 'twitter':
        return FontAwesomeIcons.xTwitter;
      case 'facebook':
        return FontAwesomeIcons.facebook;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'tiktok':
        return FontAwesomeIcons.tiktok;
      case 'youtube':
        return FontAwesomeIcons.youtube;
      case 'mastodon':
        return FontAwesomeIcons.mastodon;
      case 'github':
        return FontAwesomeIcons.github;
      case 'linkedin':
        return FontAwesomeIcons.linkedin;
      case 'reddit':
        return FontAwesomeIcons.reddit;
      default:
        return FontAwesomeIcons.link;
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
