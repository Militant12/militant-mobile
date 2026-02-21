import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../screens/call_screen.dart';
import '../screens/group_call_screen.dart';
import '../services/api_service.dart';

/// Données d'un appel entrant
class IncomingCallData {
  final String callId;
  final int callerId;
  final String callerName;
  final bool isVideo;
  final bool isGroup;
  final int? groupId;
  final String? offerSdp;

  const IncomingCallData({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.isVideo,
    required this.isGroup,
    this.groupId,
    this.offerSdp,
  });
}

/// Controller global pour diffuser les appels entrants à tous les chats ouverts
class IncomingCallController {
  IncomingCallController._();
  static final IncomingCallController instance = IncomingCallController._();

  final StreamController<IncomingCallData?> _streamController =
      StreamController<IncomingCallData?>.broadcast();

  Stream<IncomingCallData?> get stream => _streamController.stream;

  bool _isListening = false;

  void startListening() {
    if (_isListening) return;
    _isListening = true;

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data == null) {
        event.notification.display();
        return;
      }

      final type = data['type']?.toString();
      if (type != 'call') {
        event.notification.display();
        return;
      }

      // Appel entrant — on supprime la notification système et on affiche la bannière
      event.preventDefault();

      final callId = data['call_id']?.toString() ?? '';
      final callerId = int.tryParse(data['caller_id']?.toString() ?? '') ?? 0;
      final callerName =
          data['caller_name']?.toString() ??
          event.notification.body ??
          'Appel entrant';
      final isVideo = data['call_type'] == 'video' || data['is_video'] == true;
      final isGroup = data['is_group_call'] == true || data['group_id'] != null;
      final groupId = int.tryParse(data['group_id']?.toString() ?? '');
      final offerSdp = data['offer_sdp']?.toString();

      if (callId.isNotEmpty) {
        _streamController.add(
          IncomingCallData(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            isVideo: isVideo,
            isGroup: isGroup,
            groupId: groupId,
            offerSdp: offerSdp,
          ),
        );
      }
    });
  }

  void dismiss() {
    _streamController.add(null);
  }
}

/// Bannière d'appel entrant à intégrer dans n'importe quel écran de chat
///
/// Usage :
/// ```dart
/// Stack(
///   children: [
///     // ... contenu du chat ...
///     IncomingCallBanner(
///       currentUserId: myId,
///       peerId: widget.userId,       // pour filtrer les appels pertinents
///       groupId: null,
///     ),
///   ],
/// )
/// ```
class IncomingCallBanner extends StatefulWidget {
  /// ID de l'interlocuteur (pour chat privé) — null pour groupe
  final int? peerId;

  /// ID du groupe (pour chat de groupe) — null pour chat privé
  final int? groupId;

  const IncomingCallBanner({super.key, this.peerId, this.groupId});

  @override
  State<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<IncomingCallBanner>
    with SingleTickerProviderStateMixin {
  IncomingCallData? _call;
  StreamSubscription<IncomingCallData?>? _subscription;
  late AnimationController _anim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    IncomingCallController.instance.startListening();

    _subscription = IncomingCallController.instance.stream.listen((call) {
      if (!mounted) return;

      if (call == null) {
        _dismiss();
        return;
      }

      // Afficher la bannière seulement si l'appel est pertinent pour ce chat
      final relevant = _isRelevant(call);
      if (!relevant) return;

      setState(() => _call = call);
      _anim.forward(from: 0);
    });
  }

  bool _isRelevant(IncomingCallData call) {
    if (call.isGroup && widget.groupId != null) {
      return call.groupId == widget.groupId;
    }
    if (!call.isGroup && widget.peerId != null) {
      return call.callerId == widget.peerId;
    }
    // Afficher dans tous les chats si on ne peut pas filtrer
    return true;
  }

  void _dismiss() {
    if (!mounted) return;
    _anim.reverse().then((_) {
      if (mounted) setState(() => _call = null);
    });
  }

  Future<void> _accept() async {
    final call = _call;
    if (call == null) return;
    _dismiss();
    IncomingCallController.instance.dismiss();

    if (!mounted) return;

    if (call.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupCallScreen(
            groupId: call.groupId ?? 0,
            groupName: call.callerName,
            isVideo: call.isVideo,
            isIncoming: true,
            callId: call.callId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: call.callId,
            recipientId: call.callerId,
            recipientName: call.callerName,
            isVideo: call.isVideo,
            isIncoming: true,
            offerSdp: call.offerSdp ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _refuse() async {
    final call = _call;
    _dismiss();
    IncomingCallController.instance.dismiss();

    if (call != null) {
      try {
        final api = await ApiService.getInstance();
        await api.rejectCall(call.callId);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_call == null) return const SizedBox.shrink();

    final call = _call!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          elevation: 8,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          color: isDark ? const Color(0xFF1E2A3A) : const Color(0xFF0D1B2A),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icône animée (pulsée)
                  _PulsingIcon(isVideo: call.isVideo),
                  const SizedBox(width: 12),

                  // Infos appel
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          call.callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          call.isGroup
                              ? (call.isVideo
                                    ? '📹 Appel vidéo de groupe'
                                    : '📞 Appel audio de groupe')
                              : (call.isVideo
                                    ? '📹 Appel vidéo entrant'
                                    : '📞 Appel audio entrant'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Bouton Refuser
                  _CallButton(
                    icon: Icons.call_end,
                    color: const Color(0xFFE53935),
                    label: 'Refuser',
                    onTap: _refuse,
                  ),
                  const SizedBox(width: 8),

                  // Bouton Rejoindre
                  _CallButton(
                    icon: call.isVideo ? Icons.videocam : Icons.call,
                    color: const Color(0xFF43A047),
                    label: 'Rejoindre',
                    onTap: _accept,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône qui pulse pour signaler un appel entrant
class _PulsingIcon extends StatefulWidget {
  final bool isVideo;
  const _PulsingIcon({required this.isVideo});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF43A047).withValues(alpha: 0.2),
          border: Border.all(color: const Color(0xFF43A047), width: 2),
        ),
        child: Icon(
          widget.isVideo ? Icons.videocam : Icons.call,
          color: const Color(0xFF43A047),
          size: 22,
        ),
      ),
    );
  }
}

/// Bouton circulaire Rejoindre / Refuser
class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
