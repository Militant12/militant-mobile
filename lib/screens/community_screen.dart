import 'package:flutter/material.dart';
import '../services/language_service.dart';
import 'live_screen.dart';
import 'pages_screen.dart';
import 'moderation_screen.dart';
import 'discovery_screen.dart';
import 'fediverse_screen.dart';
import 'feature_suggestions_screen.dart';
import '../theme/app_colors.dart';
import '../theme/theme_context.dart';
import '../theme/app_tokens.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance,
      builder: (context, locale, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final translate = LanguageService.instance.translate;

        final backgroundColor = theme.scaffoldBackgroundColor;
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(translate('community_tab_title')),
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    translate('explore_mobilize_title'),
                    style: TextStyle(
                      color: textColor,
                      fontSize: AppTokens.fontTitleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  translate('fediverse_title'),
                  translate('fediverse_menu_desc'),
                  Icons.hub_outlined,
                  const FediverseScreen(),
                  Colors.teal[700]!,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  translate('discover'),
                  translate('discover_militants_desc'),
                  Icons.person_search,
                  const DiscoveryScreen(),
                  AppColors.militantRed,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  translate('live_title'),
                  translate('live_desc'),
                  Icons.live_tv,
                  const LiveScreen(),
                  AppColors.militantRed,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  translate('feature_suggestions'),
                  translate('suggest_features_desc'),
                  Icons.lightbulb_outline,
                  const FeatureSuggestionsScreen(),
                  const Color(0xFF6D5DF6),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  translate('pages_title'),
                  translate('pages_desc'),
                  Icons.flag,
                  const PagesScreen(),
                  Colors.blue[700]!,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  translate('mod_title'),
                  translate('moderation_desc'),
                  Icons.security,
                  const ModerationScreen(),
                  Colors.purple[700]!,
                  isDark,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget screen,
    Color accentColor,
    bool isDark,
  ) {
    Color iconColor = accentColor;
    Color iconBgColor = accentColor.withValues(alpha: 0.15);

    if (title == 'Pages' || title == 'Páginas') {
      iconColor = Colors.black;
      if (isDark) {
        iconBgColor = Colors.white;
      } else {
        iconBgColor = Colors.grey[200]!;
      }
    }

    final cardBg = isDark ? const Color(0xFF151515) : Colors.white;
    final borderColor = context.colors.outlineVariant;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.grey.withValues(alpha: 0.2);

    final gradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF252525), Color(0xFF151515)],
          )
        : null;

    final textColor = context.colors.onSurface;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 120;

              return Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isNarrow ? 6 : 8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: isNarrow ? 20 : 24,
                      color: iconColor,
                    ),
                  ),
                  SizedBox(width: isNarrow ? 8 : 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: AppTokens.fontBodyLarge,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(color: subTextColor, fontSize: AppTokens.fontBodySmall),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow)
                    Icon(
                      Icons.arrow_forward_ios,
                      color: context.colors.outlineVariant,
                      size: 16,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
