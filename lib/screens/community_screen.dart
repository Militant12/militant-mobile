import 'package:flutter/material.dart';
import '../services/language_service.dart';
import 'groups_screen.dart';
import 'events_screen.dart';
import 'pages_screen.dart';
import 'moderation_screen.dart';

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

        // Couleurs adaptées au thème
        final backgroundColor = theme.scaffoldBackgroundColor;
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(translate('community_tab_title')),
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  translate('explore_mobilize_title'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildMenuCard(
                context,
                translate('groups_title'),
                translate('groups_desc'),
                Icons.group,
                const GroupsScreen(),
                const Color(0xFFBE1E1E), // Militant Red (Brand)
                isDark,
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                translate('events_title'),
                translate('events_desc'),
                Icons.event,
                const EventsScreen(),
                Colors.orange[800]!,
                isDark,
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                translate('pages_title'),
                translate('pages_desc'),
                Icons.flag,
                const PagesScreen(),
                Colors.blue[700]!, // Blue but handled with Black Flag logic
                isDark,
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                translate('mod_title'), // Uses existing key
                translate('moderation_desc'),
                Icons.security,
                const ModerationScreen(),
                Colors.purple[700]!,
                isDark,
              ),
            ],
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
    // Si la couleur est noire (Drapeau Noir) ET qu'on est en mode sombre, on adapte
    // Mais ici accentColor pour Pages est bleu, on va gérer le cas spécifique
    // Pour Pages, on veut un drapeau noir.
    // Si le thème est clair, drapeau noir sur fond clair passe.
    // Si le thème est sombre, drapeau noir sur fond blanc passe.

    // Logique spécifique pour l'icône Pages (qui est bleue ici pour uniformité code mais on veut effet drapeau noir ?)
    // Non, restons sur les couleurs de marque.
    // POur "Pages", l'utilisateur voulait un drapeau noir.
    // Je vais tricher : si title correspond à 'Pages' (ou traduit), on force le noir.

    Color iconColor = accentColor;
    Color iconBgColor = accentColor.withOpacity(0.15);

    // Special handling for Pages/Black Flag request
    if (title == 'Pages' || title == 'Páginas') {
      // Simple detection
      iconColor = Colors.black;
      // On dark mode, black icon needs white background circle
      if (isDark) {
        iconBgColor = Colors.white;
      } else {
        iconBgColor = Colors.grey[200]!;
      }
    }

    // Card background
    final cardBg = isDark ? const Color(0xFF151515) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey[300]!;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.4)
        : Colors.grey.withOpacity(0.2);

    // Gradient only for dark mode to keep "premium" look, flat/clean for light mode
    final gradient = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF252525), const Color(0xFF151515)],
          )
        : null;

    final textColor = isDark ? Colors.white : Colors.black;
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? Colors.white24 : Colors.black12,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
