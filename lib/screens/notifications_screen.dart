import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
import 'group_detail_screen.dart';
import '../models/post.dart';
import '../utils/date_formatter.dart';

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

  int? _extractGroupId(dynamic notif) {
    final directId = int.tryParse(notif['group_id']?.toString() ?? '');
    if (directId != null && directId > 0) {
      return directId;
    }

    final metadata = notif['metadata'];
    if (metadata is Map) {
      final metadataId = int.tryParse(metadata['group_id']?.toString() ?? '');
      if (metadataId != null && metadataId > 0) {
        return metadataId;
      }
    }

    final link = notif['link']?.toString() ?? '';
    final match = RegExp(r'group_detail\.php\?id=(\d+)').firstMatch(link);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  Future<void> _openGroupDetails(int groupId) async {
    final api = await ApiService.getInstance();
    final groupData = await api.getSocialGroupDetails(groupId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(group: groupData)),
    );
  }

  Future<void> _showGroupInviteDialog(dynamic notif) async {
    final translate = LanguageService.instance.translate;
    final groupId = _extractGroupId(notif);
    if (groupId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('notification_group_invite_missing'))),
      );
      return;
    }

    final username = notif['from_username'] ?? notif['username'] ?? 'Militant';
    final groupName =
        notif['group_name']?.toString().trim().isNotEmpty == true
        ? notif['group_name'].toString().trim()
        : translate('notification_group_invite_fallback_group');

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          translate('notification_group_invite_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          translate(
            'notification_group_invite_message',
          ).replaceFirst('{user}', username.toString()).replaceFirst(
            '{group}',
            groupName,
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('open'),
            child: Text(translate('notification_group_invite_view')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('accept'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBE1E1E),
            ),
            child: Text(translate('accept')),
          ),
        ],
      ),
    );

    if (action == null) return;

    try {
      final api = await ApiService.getInstance();
      if (action == 'accept') {
        final result = await api.joinGroup(groupId);
        if (!mounted) return;
        final message =
            result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString().trim()
            : translate('notification_group_invite_accepted');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      await _openGroupDetails(groupId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${translate('error')}: $e')));
    }
  }

  Future<void> _handleNotificationTap(dynamic notif) async {
    final type = notif['type'] ?? 'notification';
    final username = notif['from_username'] ?? notif['username'] ?? 'Militant';

    if (type == 'follow' ||
        type == 'friend_request' ||
        type == 'friend_accept') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: notif['from_user_id']),
        ),
      );
      return;
    }

    if (type == 'message' || type == 'message_request') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(userId: notif['from_user_id'], username: username),
        ),
      );
      return;
    }

    if (type == 'group_invite') {
      await _showGroupInviteDialog(notif);
      return;
    }

    if (type == 'group_join_request' ||
        type == 'group_join_approved' ||
        type == 'group_join_rejected') {
      final groupId = _extractGroupId(notif);
      if (groupId == null) return;
      try {
        await _openGroupDetails(groupId);
      } catch (e) {
        if (!mounted) return;
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
      }
      return;
    }

    if ((type == 'like' ||
            type == 'comment' ||
            type == 'mention' ||
            type == 'reaction') &&
        notif['post_id'] != null) {
      try {
        final api = await ApiService.getInstance();
        final postData = await api.getPost(notif['post_id']);
        if (!mounted) return;
        if (postData.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: Post.fromJson(postData)),
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
      onTap: () => _handleNotificationTap(notif),
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
      final date = DateFormatter.parseApiDate(dateStr);
      return DateFormatter.formatRelative(date);
    } catch (e) {
      return dateStr;
    }
  }
}
