import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
import 'group_detail_screen.dart';
import '../models/post.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<dynamic> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final notifications = await api.getNotifications();
      setState(() {
        _notifications.clear();
        _notifications.addAll(notifications);
      });
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    
    return ValueListenableBuilder<Locale>(
      valueListenable: lang,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              lang.translate('notifications_title'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                )
              : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        lang.translate('no_notifications'),
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFFBE1E1E),
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return _buildNotificationItem(notif);
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildNotificationItem(dynamic notif) {
    final lang = LanguageService.instance;
    final type = notif['type'] ?? 'notification';
    final username = notif['from_username'] ?? notif['username'] ?? 'Militant';
    final createdAt = notif['created_at'] ?? '';
    final reactionType = notif['reaction_type']; // Pour les réactions SVG

    // Toujours utiliser les traductions selon le type de notification
    String message;
    switch (type) {
      case 'like':
        message = lang.translate('notification_like');
        break;
      case 'comment':
        message = lang.translate('notification_comment');
        break;
      case 'follow':
        message = lang.translate('notification_follow');
        break;
      case 'mention':
        message = lang.translate('notification_mention');
        break;
      case 'reaction':
        message = lang.translate('notification_reaction');
        break;
      case 'message':
        message = lang.translate('notification_message');
        break;
      case 'message_request':
        message = lang.translate('notification_message_request');
        break;
      case 'friend_request':
        message = lang.translate('notification_friend_request');
        break;
      case 'friend_accept':
        message = lang.translate('notification_friend_accept');
        break;
      case 'group_invite':
        message = lang.translate('notification_group_invite');
        break;
      case 'group_join_request':
        message = lang.translate('notification_group_join_request');
        break;
      case 'group_join_approved':
        message = lang.translate('notification_group_join_approved');
        break;
      case 'group_join_rejected':
        message = lang.translate('notification_group_join_rejected');
        break;
      case 'event_invite':
        message = lang.translate('notification_event_invite');
        break;
      case 'share':
        message = lang.translate('notification_post_share');
        break;
      default:
        // Si type inconnu, utiliser le contenu de la base de données
        var rawMessage = notif['content'] ?? notif['message'] ?? '';
        // Nettoyer le message: enlever le code SVG s'il est présent
        rawMessage = rawMessage.replaceAll(RegExp(r'<svg[^>]*>.*?</svg>', dotAll: true), '').trim();
        message = rawMessage.isNotEmpty ? rawMessage : lang.translate('notification_generic');
    }

    return InkWell(
      onTap: () async {
        if (type == 'follow' ||
            type == 'friend_request' ||
            type == 'friend_accept') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: notif['from_user_id']),
            ),
          );
        } else if (type == 'message' || type == 'message_request') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(userId: notif['from_user_id'], username: username),
            ),
          );
        } else if (type == 'group_join_request') {
          // Rediriger vers l'écran des demandes d'adhésion du groupe
          final link = notif['link'];
          if (link != null && link.toString().contains('group_detail.php?id=')) {
            final groupId = int.tryParse(
              link.toString().split('id=').last.split('&').first,
            );
            if (groupId != null) {
              // Charger les détails du groupe et naviguer
              try {
                final api = await ApiService.getInstance();
                final groupData = await api.getSocialGroupDetails(groupId);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailScreen(group: groupData),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                final lang = LanguageService.instance;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
              }
            }
          }
        } else if (type == 'group_join_approved' || type == 'group_join_rejected') {
          // Rediriger vers la page du groupe
          final link = notif['link'];
          if (link != null && link.toString().contains('group_detail.php?id=')) {
            final groupId = int.tryParse(
              link.toString().split('id=').last.split('&').first,
            );
            if (groupId != null) {
              try {
                final api = await ApiService.getInstance();
                final groupData = await api.getSocialGroupDetails(groupId);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailScreen(group: groupData),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                final lang = LanguageService.instance;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
              }
            }
          }
        } else if ((type == 'like' || type == 'comment' || type == 'mention' || type == 'reaction') &&
            notif['post_id'] != null) {
          try {
            final api = await ApiService.getInstance();
            final postData = await api.getPost(notif['post_id']);
            if (!mounted) return;
            if (postData.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PostDetailScreen(post: Post.fromJson(postData)),
                ),
              );
            }
          } catch (e) {
            if (!mounted) return;
            final lang = LanguageService.instance;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFBE1E1E).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: _buildNotificationIcon(type, reactionType),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      children: [
                        TextSpan(
                          text: username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' $message'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
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

  Widget _buildNotificationIcon(String type, String? reactionType) {
    // Si c'est une réaction avec un type spécifique, utiliser le SVG approprié
    if (type == 'reaction' || type == 'like') {
      if (reactionType == 'thumbs_up' || type == 'like') {
        return SvgPicture.asset(
          'assets/thumbs-up-red-black.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            Color(0xFFBE1E1E),
            BlendMode.srcIn,
          ),
        );
      }
      // Autres réactions SVG peuvent être ajoutées ici
    }

    // Icônes par défaut
    IconData icon;
    switch (type) {
      case 'like':
      case 'reaction':
        icon = Icons.favorite;
        break;
      case 'comment':
        icon = Icons.comment;
        break;
      case 'follow':
      case 'friend_request':
      case 'friend_accept':
        icon = Icons.person_add;
        break;
      case 'mention':
        icon = Icons.alternate_email;
        break;
      default:
        icon = Icons.notifications;
    }

    return Icon(
      icon,
      color: const Color(0xFFBE1E1E),
      size: 20,
    );
  }

  String _formatDate(String dateStr) {
    try {
      final lang = LanguageService.instance;
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return lang.translate('just_now');
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}${lang.translate('minutes_short')}';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}${lang.translate('hours_short')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}${lang.translate('days_short')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}
