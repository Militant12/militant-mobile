import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getNotificationIcon(String type) {
    // Cette méthode est maintenant remplacée par _buildNotificationIcon
    // mais gardée pour compatibilité
    switch (type) {
      case 'like':
      case 'reaction':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'mention':
        return Icons.alternate_email;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Color(0xFF888888),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 16),
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
  }

  Widget _buildNotificationItem(dynamic notif) {
    final type = notif['type'] ?? 'notification';
    var message = notif['content'] ?? notif['message'] ?? '';
    final username = notif['from_username'] ?? notif['username'] ?? 'Militant';
    final createdAt = notif['created_at'] ?? '';
    final reactionType = notif['reaction_type']; // Pour les réactions SVG

    // Nettoyer le message: enlever le code SVG s'il est présent
    message = message.replaceAll(RegExp(r'<svg[^>]*>.*?</svg>', dotAll: true), '').trim();

    return InkWell(
      onTap: () async {
        if (type == 'follow') {
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
        } else if ((type == 'like' || type == 'comment' || type == 'mention' || type == 'reaction') &&
            notif['post_id'] != null) {
          try {
            final api = await ApiService.getInstance();
            final postData = await api.getPost(notif['post_id']);
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
                color: const Color(0xFFBE1E1E).withOpacity(0.2),
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
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}min';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}j';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}
