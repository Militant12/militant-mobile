import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../screens/call_screen.dart';
import '../screens/group_call_screen.dart';
import '../services/api_service.dart';

String? _payloadString(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return null;

  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final normalized = value.toString().trim();
    if (normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'undefined') {
      continue;
    }
    return normalized;
  }

  return null;
}

bool _payloadBool(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return false;

  for (final key in keys) {
    final value = data[key];
    if (value is bool) return value;

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) continue;
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }

  return false;
}

String? _payloadOfferSdp(Map<String, dynamic>? data) {
  return _payloadString(data, const ['offer_sdp', 'offerSdp', 'offer']);
}

String? _payloadAvatar(Map<String, dynamic>? data) {
  final rawAvatar = _payloadString(data, const [
    'caller_avatar',
    'callerAvatar',
    'avatar',
    'profile_picture',
    'profilePicture',
    'user_avatar',
    'userAvatar',
  ]);
  if (rawAvatar == null) return null;
  return ApiService(baseUrl: '').getImageUrl(rawAvatar) ?? rawAvatar;
}

/// Données d'un appel entrant
class IncomingCallData {
  final String callId;
  final int callerId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final bool isGroup;
  final int? groupId;
  final String? offerSdp;

  const IncomingCallData({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
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
  Timer? _fallbackPollTimer;
  bool _isPollingFallback = false;
  String? _activeCallId;
  final Set<String> _dismissedCallIds = <String>{};

  void startListening() {
    if (_isListening) return;

    // Sur Android on s'appuie uniquement sur la notification d'appel native
    // pour éviter le doublon "notification système + bannière dans l'app".
    if (!kIsWeb && Platform.isAndroid) {
      return;
    }

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
          _payloadString(data, const ['caller_name', 'callerName']) ??
          event.notification.body ??
          'Appel entrant';

      final isVideo =
          _payloadString(data, const ['call_type', 'callType']) == 'video' ||
          _payloadBool(data, const ['is_video', 'isVideo']);
      final isGroup =
          _payloadBool(data, const ['is_group_call', 'isGroupCall']) ||
          _payloadString(data, const ['group_id', 'groupId']) != null;
      final groupId = int.tryParse(data['group_id']?.toString() ?? '');
      final offerSdp = _payloadOfferSdp(data);

      if (callId.isNotEmpty) {
        _emitIncomingCall(
          IncomingCallData(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerAvatar: _payloadAvatar(data),
            isVideo: isVideo,
            isGroup: isGroup,
            groupId: groupId,
            offerSdp: offerSdp,
          ),
        );
      }
    });

    _startFallbackPolling();
  }

  void _emitIncomingCall(IncomingCallData call) {
    if (_dismissedCallIds.contains(call.callId) ||
        _activeCallId == call.callId) {
      return;
    }

    _activeCallId = call.callId;
    _streamController.add(call);
  }

  void _startFallbackPolling() {
    _fallbackPollTimer?.cancel();
    _pollIncomingPrivateCalls();
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollIncomingPrivateCalls();
    });
  }

  Future<void> _pollIncomingPrivateCalls() async {
    if (_isPollingFallback) return;
    _isPollingFallback = true;

    try {
      final api = await ApiService.getInstance();
      final history = await api.getCallHistory(page: 1);

      for (final item in history) {
        if (item is! Map) continue;
        final call = Map<String, dynamic>.from(item);
        final callId = call['call_id']?.toString() ?? '';
        final direction = call['direction']?.toString();
        final status = call['status']?.toString();
        final isGroup =
            call['is_group_call'] == true ||
            call['is_group_call']?.toString() == '1';

        if (callId.isEmpty ||
            direction != 'incoming' ||
            status != 'ringing' ||
            isGroup) {
          continue;
        }

        _emitIncomingCall(
          IncomingCallData(
            callId: callId,
            callerId: int.tryParse(call['caller_id']?.toString() ?? '') ?? 0,
            callerName:
                call['caller_username']?.toString().trim().isNotEmpty == true
                ? call['caller_username'].toString()
                : 'Appel entrant',
            callerAvatar: _payloadAvatar(call),
            isVideo: call['call_type']?.toString() == 'video',
            isGroup: false,
            offerSdp: _payloadOfferSdp(call),
          ),
        );
        break;
      }
    } catch (_) {
      // Ignore fallback polling errors; push handling remains the primary path.
    } finally {
      _isPollingFallback = false;
    }
  }

  void dismiss([String? callId]) {
    final effectiveCallId = callId ?? _activeCallId;
    if (effectiveCallId != null && effectiveCallId.isNotEmpty) {
      _dismissedCallIds.add(effectiveCallId);
      if (_dismissedCallIds.length > 20) {
        _dismissedCallIds.remove(_dismissedCallIds.first);
      }
    }
    if (_activeCallId == effectiveCallId) {
      _activeCallId = null;
    }
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
    IncomingCallController.instance.dismiss(call.callId);

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
            recipientAvatar: call.callerAvatar,
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
    IncomingCallController.instance.dismiss(call?.callId);

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = const Color(0xFFBE1E1E);
    final surface = colorScheme.surface;
    final onSurface = colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.72);
    final border = onSurface.withValues(alpha: 0.10);

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
          color: surface,
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
                          style: TextStyle(
                            color: onSurface,
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
                                    ? 'Appel vidéo de groupe'
                                    : 'Appel audio de groupe')
                              : (call.isVideo
                                    ? 'Appel vidéo entrant'
                                    : 'Appel audio entrant'),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Bouton Refuser
                  _CallButton(
                    icon: Icons.call_end,
                    color: accent,
                    foregroundColor: Colors.white,
                    backgroundColor: accent,
                    outlined: false,
                    label: 'Refuser',
                    labelColor: muted,
                    onTap: _refuse,
                  ),
                  const SizedBox(width: 8),

                  // Bouton Rejoindre
                  _CallButton(
                    icon: call.isVideo ? Icons.videocam : Icons.call,
                    color: accent,
                    foregroundColor: onSurface,
                    backgroundColor: surface,
                    borderColor: border,
                    outlined: true,
                    label: call.isGroup ? 'Rejoindre' : 'Répondre',
                    labelColor: muted,
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
    final accent = const Color(0xFFBE1E1E);
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.12),
          border: Border.all(color: accent, width: 2),
        ),
        child: Icon(
          widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          color: accent,
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
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Color labelColor;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.foregroundColor,
    required this.backgroundColor,
    this.borderColor,
    required this.labelColor,
    required this.label,
    required this.onTap,
    required this.outlined,
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              border: outlined ? Border.all(color: borderColor ?? color) : null,
            ),
            child: Icon(icon, color: foregroundColor, size: 22),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: labelColor, fontSize: 10)),
        ],
      ),
    );
  }
}
