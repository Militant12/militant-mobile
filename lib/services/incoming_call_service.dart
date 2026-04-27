import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../screens/call_screen.dart';
import '../screens/group_call_screen.dart';
import 'api_service.dart';
import 'call_kit_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String _generateFallbackCallId() =>
    DateTime.now().microsecondsSinceEpoch.toString();

class IncomingCallService {
  IncomingCallService._internal();
  static final IncomingCallService instance = IncomingCallService._internal();
  static const MethodChannel _callsChannel = MethodChannel(
    'com.militant.militant_flutter/calls',
  );

  final CallKitService _callKit = CallKitService();
  bool _isInitialized = false;
  bool _isAndroidCallBridgeReady = false;
  String? _activeForegroundDialogCallId;
  Map<String, dynamic>? _pendingAndroidIncomingIntent;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    _callKit.init(
      onAccept: _handleCallAccept,
      onDecline: _handleCallDecline,
      onEnded: _handleCallEnded,
    );

    OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
      final data = event.notification.additionalData;

      if (_isGroupCallNotification(data)) {
        event.preventDefault();
        _showIncomingGroupCallDialog(
          data: data!,
          body: event.notification.body,
        );
        return;
      }

      // ─── Appel 1-to-1 classique ──────────────────────────────────────────
      if (!_isCallNotification(data)) {
        event.notification.display();
        return;
      }

      event.preventDefault();
      final hydratedData = await _resolveIncomingCallMetadata(data!);
      _showIncomingPrivateCallDialog(
        data: hydratedData,
        body: event.notification.body,
      );
    });

    OneSignal.Notifications.addClickListener((event) async {
      final data = event.notification.additionalData;

      if (_isGroupCallNotification(data)) {
        _openIncomingGroupCallScreen(
          data: data!,
          callerName: event.notification.body ?? 'Appel de groupe',
        );
        return;
      }

      // ─── Clic sur un appel 1-to-1 classique ─────────────────────────────
      if (!_isCallNotification(data)) return;

      final hydratedData = data == null
          ? <String, dynamic>{}
          : await _resolveIncomingCallMetadata(data);

      _openIncomingCallScreen(
        callId: _parseCallId(
          raw: hydratedData['call_id'],
          fallback: _generateFallbackCallId(),
        ),
        callerId: _callerIdFromPayload(hydratedData),
        callerName:
            _callerNameFromPayload(
              hydratedData,
              fallback: event.notification.body ?? 'Appel entrant',
            ) ??
            'Appel entrant',
        callerAvatar: _avatarFromPayload(hydratedData),
        isVideo: _isVideoCall(hydratedData),
        offerSdp: _offerSdpFromPayload(hydratedData),
      );
    });

    await _initializeAndroidCallBridge();

    _isInitialized = true;
  }

  // ─── Détection du type de notification ────────────────────────────────────

  bool _isCallNotification(Map<String, dynamic>? data) {
    return data != null && data['type'] == 'call';
  }

  Map<String, dynamic> _mergeIncomingPayload(
    Map<String, dynamic> base,
    Map<String, dynamic>? extra,
  ) {
    final merged = Map<String, dynamic>.from(base);
    if (extra == null) return merged;

    void mergeMap(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((key, value) {
        final existing = merged[key];
        final normalizedExisting = existing?.toString().trim() ?? '';
        final hasExisting =
            normalizedExisting.isNotEmpty &&
            normalizedExisting != 'null' &&
            normalizedExisting != 'undefined';
        if (!hasExisting && value != null) {
          merged[key] = value;
        }
      });
    }

    mergeMap(extra);

    for (final nested in <dynamic>[
      extra['call'],
      extra['caller'],
      extra['user'],
      extra['initiator'],
      extra['recipient'],
    ]) {
      if (nested is Map) {
        mergeMap(Map<String, dynamic>.from(nested));
      }
    }

    return merged;
  }

  String? _stringFromPayload(Map<String, dynamic>? data, List<String> keys) {
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

  String? _callerNameFromPayload(
    Map<String, dynamic>? data, {
    String? fallback,
  }) {
    return _stringFromPayload(data, const [
          'caller_name',
          'callerName',
          'name',
          'display_name',
          'displayName',
          'full_name',
          'fullName',
          'username',
          'pseudo',
          'title',
        ]) ??
        fallback;
  }

  bool _looksLikeNotificationBody(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return false;

    return normalized == 'appel entrant' ||
        normalized == 'appel audio entrant' ||
        normalized == 'appel video entrant' ||
        normalized == 'appel vidéo entrant' ||
        normalized == 'appel de groupe' ||
        normalized == 'appel de groupe entrant' ||
        normalized.endsWith(' vous appelle');
  }

  int? _callerIdFromPayload(Map<String, dynamic>? data) {
    return _parseUserId(
      _stringFromPayload(data, const [
        'caller_id',
        'callerId',
        'user_id',
        'userId',
        'id',
      ]),
    );
  }

  bool _boolFromPayload(Map<String, dynamic>? data, List<String> keys) {
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

  String? _offerSdpFromPayload(Map<String, dynamic>? data) {
    return _stringFromPayload(data, const ['offer_sdp', 'offerSdp', 'offer']);
  }

  String? _avatarFromPayload(Map<String, dynamic>? data) {
    final rawAvatar = _stringFromPayload(data, const [
      'caller_avatar',
      'callerAvatar',
      'avatar',
      'photo',
      'picture',
      'profile_picture',
      'profilePicture',
      'user_avatar',
      'userAvatar',
    ]);
    if (rawAvatar == null) return null;
    return ApiService(baseUrl: '').getImageUrl(rawAvatar) ?? rawAvatar;
  }

  Future<Map<String, dynamic>> _resolveIncomingCallMetadata(
    Map<String, dynamic> data,
  ) async {
    final callId = _parseCallId(raw: data['call_id'], fallback: '');
    if (callId.isEmpty) return data;

    if (_callerNameFromPayload(data) != null &&
        _avatarFromPayload(data) != null &&
        _callerIdFromPayload(data) != null) {
      return data;
    }

    try {
      final api = await ApiService.getInstance();
      final callInfo = await api.getCallInfo(callId);
      final merged = _mergeIncomingPayload(data, callInfo);
      final rawAvatar = _stringFromPayload(merged, const [
        'caller_avatar',
        'callerAvatar',
        'avatar',
        'photo',
        'picture',
        'profile_picture',
        'profilePicture',
        'user_avatar',
        'userAvatar',
      ]);
      final resolvedAvatar = api.getImageUrl(rawAvatar) ?? rawAvatar;
      if (resolvedAvatar != null && resolvedAvatar.isNotEmpty) {
        merged['caller_avatar'] = resolvedAvatar;
        merged['callerAvatar'] = resolvedAvatar;
      }
      return merged;
    } catch (e) {
      debugPrint(
        '[IncomingCallService] metadata fetch failed callId=$callId error=$e',
      );
      return data;
    }
  }

  bool _isGroupCallNotification(Map<String, dynamic>? data) {
    return _isCallNotification(data) &&
        (_stringFromPayload(data, const ['group_id', 'groupId']) != null ||
            _boolFromPayload(data, const ['is_group_call', 'isGroupCall']));
  }

  bool _isVideoCall(Map<String, dynamic>? data) {
    return _boolFromPayload(data, const ['is_video', 'isVideo']) ||
        _stringFromPayload(data, const ['call_type', 'callType']) == 'video';
  }

  int? _parseUserId(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String _parseCallId({required dynamic raw, required String fallback}) {
    final value = raw?.toString().trim() ?? '';
    return value.isNotEmpty ? value : fallback;
  }

  Future<void> _showAndroidIncomingCallUi({
    required String callId,
    required String callerName,
    required bool isVideo,
    required Map<String, dynamic> extra,
  }) async {
    final api = await ApiService.getInstance();
    final callerAvatar = _avatarFromPayload(extra);
    final callerId = _callerIdFromPayload(extra);
    final payload = <String, dynamic>{
      'type': extra['type']?.toString() ?? 'call',
      'callId': callId,
      'call_id': callId,
      'callerId': callerId?.toString(),
      'caller_id': callerId?.toString(),
      'callerName': callerName,
      'caller_name': callerName,
      'callerAvatar': callerAvatar,
      'caller_avatar': callerAvatar,
      'call_type': isVideo ? 'video' : 'audio',
      'isVideo': isVideo,
      'is_video': isVideo,
      'offerSdp': _offerSdpFromPayload(extra),
      'offer_sdp': _offerSdpFromPayload(extra),
      'is_group_call': _boolFromPayload(extra, const [
        'is_group_call',
        'isGroupCall',
      ]),
      'group_id': _stringFromPayload(extra, const ['group_id', 'groupId']),
      'group_name': _stringFromPayload(extra, const [
        'group_name',
        'groupName',
      ]),
      'token': api.token ?? '',
      'baseUrl': api.apiUrl,
    };

    await _callKit.showIncomingCall(
      uuid: callId,
      callerName: callerName,
      callerAvatar: callerAvatar ?? '',
      isVideo: isVideo,
      extra: payload,
    );
  }

  Future<void> _initializeAndroidCallBridge() async {
    if (!Platform.isAndroid || _isAndroidCallBridgeReady) return;

    _callsChannel.setMethodCallHandler((call) async {
      if (call.method != 'incomingCallIntent') return;

      final arguments = call.arguments;
      if (arguments is Map) {
        _handleAndroidIncomingCallIntent(Map<String, dynamic>.from(arguments));
      }
    });

    _isAndroidCallBridgeReady = true;

    try {
      final initialData = await _callsChannel.invokeMapMethod<String, dynamic>(
        'getInitialIncomingCallIntent',
      );
      if (initialData != null && initialData.isNotEmpty) {
        _pendingAndroidIncomingIntent = Map<String, dynamic>.from(initialData);
      }
    } catch (e) {
      debugPrint('[IncomingCallService] Android call bridge unavailable: $e');
    }
  }

  Future<void> flushPendingAndroidIncomingIntent() async {
    final pendingData = _pendingAndroidIncomingIntent;
    if (pendingData == null || pendingData.isEmpty) return;
    _pendingAndroidIncomingIntent = null;
    await _handleAndroidIncomingCallIntent(Map<String, dynamic>.from(pendingData));
  }

  Future<void> _handleAndroidIncomingCallIntent(Map<String, dynamic> data) async {
    final hydratedData = await (() async {
      if (_isGroupCallNotification(data)) {
        return data;
      }

      final needsHydration =
          _callerIdFromPayload(data) == null ||
          _avatarFromPayload(data) == null ||
          _looksLikeNotificationBody(_callerNameFromPayload(data));

      if (!needsHydration) {
        return data;
      }

      return _resolveIncomingCallMetadata(data);
    })();

    if (_isGroupCallNotification(hydratedData)) {
      _openIncomingGroupCallScreen(
        data: hydratedData,
        callerName:
            _stringFromPayload(hydratedData, const [
              'caller_name',
              'callerName',
              'group_name',
              'groupName',
            ]) ??
            'Appel de groupe',
      );
      return;
    }

    final callId = _parseCallId(
      raw: hydratedData['call_id'],
      fallback: _generateFallbackCallId(),
    );

    if (callId.isEmpty) return;

    final isVideo = _isVideoCall(hydratedData);
    final callerName =
        _callerNameFromPayload(
          hydratedData,
          fallback: _stringFromPayload(hydratedData, const ['title']),
        ) ??
        'Appel entrant';

    _openIncomingCallScreen(
      callId: callId,
      callerId: _callerIdFromPayload(hydratedData),
      callerName: callerName,
      callerAvatar: _avatarFromPayload(hydratedData),
      isVideo: isVideo,
      offerSdp: _offerSdpFromPayload(hydratedData),
    );
  }

  // ─── Appel 1-to-1 : Affichage CallKit natif ──────────────────────────────

  Future<void> _showIncomingPrivateCallDialog({
    required Map<String, dynamic> data,
    required String? body,
  }) async {
    final hydratedData = await _resolveIncomingCallMetadata(data);

    if (Platform.isAndroid) {
      final callId = _parseCallId(raw: hydratedData['call_id'], fallback: '');
      if (callId.isEmpty || _activeForegroundDialogCallId == callId) return;
      _activeForegroundDialogCallId = callId;
      await _showAndroidIncomingCallUi(
        callId: callId,
        callerName:
            _callerNameFromPayload(
              hydratedData,
              fallback: body ?? 'Appel entrant',
            ) ??
            'Appel entrant',
        isVideo: _isVideoCall(hydratedData),
        extra: hydratedData,
      );
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final context = navigator.overlay?.context;
    if (context == null) return;
    if (!context.mounted) return;

    final callId = _parseCallId(raw: hydratedData['call_id'], fallback: '');
    if (callId.isEmpty || _activeForegroundDialogCallId == callId) return;

    _activeForegroundDialogCallId = callId;

    final callerName =
        _callerNameFromPayload(hydratedData, fallback: body) ?? 'Appel entrant';
    final callerId = _callerIdFromPayload(hydratedData);
    final callerAvatar = _avatarFromPayload(hydratedData);
    final isVideo = _isVideoCall(hydratedData);
    final offerSdp = _offerSdpFromPayload(hydratedData);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final accent = const Color(0xFFBE1E1E);
        final surface = theme.colorScheme.surface;
        final onSurface = theme.colorScheme.onSurface;
        final mutedColor = onSurface.withValues(alpha: 0.72);
        final borderColor = onSurface.withValues(alpha: 0.12);

        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isVideo ? 'Appel vidéo entrant' : 'Appel audio entrant',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Conversation privée',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callerName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isVideo
                      ? 'Un appel vidéo privé est en attente.'
                      : 'Un appel audio privé est en attente.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: onSurface,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _rejectIncomingCall(callId);
                },
                child: const Text('Refuser'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openIncomingCallScreen(
                    callId: callId,
                    callerId: callerId,
                    callerName: callerName,
                    callerAvatar: callerAvatar,
                    isVideo: isVideo,
                    offerSdp: offerSdp,
                  );
                },
                child: const Text('Répondre'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (_activeForegroundDialogCallId == callId) {
        _activeForegroundDialogCallId = null;
      }
    });
  }

  Future<void> _rejectIncomingCall(String callId) async {
    if (_activeForegroundDialogCallId == callId) {
      _activeForegroundDialogCallId = null;
    }
    try {
      final api = await ApiService.getInstance();
      await api.rejectCall(callId);
    } catch (e) {
      debugPrint('Call reject sync failed: $e');
    }

    try {
      await _callKit.endCall(callId);
    } catch (e) {
      debugPrint('CallKit endCall failed: $e');
    }
  }

  void _handleCallAccept(String uuid, Map<String, dynamic>? extra) {
    if (_isGroupCallNotification(extra)) {
      _openIncomingGroupCallScreen(
        data: Map<String, dynamic>.from(extra ?? const <String, dynamic>{}),
        callerName:
            _stringFromPayload(extra, const [
              'caller_name',
              'callerName',
              'group_name',
              'groupName',
            ]) ??
            'Appel de groupe',
      );
      return;
    }

    _openIncomingCallScreen(
      callId: _parseCallId(raw: extra?['callId'], fallback: uuid),
      callerId: _callerIdFromPayload(extra),
      callerName:
          _callerNameFromPayload(
            extra,
            fallback: extra?['callerName']?.toString() ?? 'Appel entrant',
          ) ??
          'Appel entrant',
      callerAvatar: _avatarFromPayload(extra),
      isVideo: extra?['isVideo'] == true || extra?['isVideo'] == 'true',
      offerSdp: _offerSdpFromPayload(extra),
    );
  }

  Future<void> _handleCallDecline(
    String uuid,
    Map<String, dynamic>? extra,
  ) async {
    final callId = _parseCallId(
      raw: extra?['callId'] ?? extra?['call_id'],
      fallback: uuid,
    );
    await _rejectIncomingCall(callId);
  }

  Future<void> _handleCallEnded(
    String uuid,
    Map<String, dynamic>? extra,
  ) async {
    try {
      await _callKit.endCall(uuid);
    } catch (e) {
      debugPrint('CallKit endCall failed: $e');
    }
  }

  void _openIncomingCallScreen({
    required String callId,
    required int? callerId,
    required String callerName,
    String? callerAvatar,
    required bool isVideo,
    String? offerSdp,
  }) {
    if (_activeForegroundDialogCallId == callId) {
      _activeForegroundDialogCallId = null;
    }
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator unavailable, cannot open call screen for $callId');
      _pendingAndroidIncomingIntent = <String, dynamic>{
        'type': 'call',
        'call_id': callId,
        'caller_id': callerId?.toString(),
        'caller_name': callerName,
        'caller_avatar': callerAvatar,
        'call_type': isVideo ? 'video' : 'audio',
        'is_video': isVideo,
        'offer_sdp': offerSdp,
      };
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          recipientId: callerId,
          recipientName: callerName,
          recipientAvatar: callerAvatar,
          isVideo: isVideo,
          isIncoming: true,
          offerSdp: offerSdp,
        ),
      ),
    );
  }

  void _showIncomingGroupCallDialog({
    required Map<String, dynamic> data,
    required String? body,
  }) {
    if (Platform.isAndroid) {
      final callId = _parseCallId(raw: data['call_id'], fallback: '');
      if (callId.isEmpty || _activeForegroundDialogCallId == callId) return;
      _activeForegroundDialogCallId = callId;
      _showAndroidIncomingCallUi(
        callId: callId,
        callerName:
            _stringFromPayload(data, const [
              'caller_name',
              'callerName',
              'group_name',
              'groupName',
            ]) ??
            body ??
            'Appel de groupe entrant',
        isVideo: _isVideoCall(data),
        extra: data,
      );
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final context = navigator.overlay?.context;
    if (context == null) return;

    final callId = _parseCallId(raw: data['call_id'], fallback: '');
    if (callId.isEmpty) {
      debugPrint('[IncomingCallService] call_id groupe manquant, ignoré.');
      return;
    }
    if (_activeForegroundDialogCallId == callId) return;

    final callerName = body ?? 'Appel de groupe entrant';
    final isVideo = _isVideoCall(data);

    _activeForegroundDialogCallId = callId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final accent = const Color(0xFFBE1E1E);
        final surface = theme.colorScheme.surface;
        final onSurface = theme.colorScheme.onSurface;
        final mutedColor = onSurface.withValues(alpha: 0.72);
        final borderColor = onSurface.withValues(alpha: 0.12);

        return AlertDialog(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVideo
                          ? 'Appel vidéo de groupe'
                          : 'Appel audio de groupe',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conversation de groupe',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                callerName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVideo
                    ? 'Un appel vidéo de groupe est en attente.'
                    : 'Un appel audio de groupe est en attente.',
                style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurface,
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _rejectIncomingCall(callId);
              },
              child: const Text('Refuser'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Rejoindre'),
              onPressed: () {
                Navigator.pop(ctx);
                _openIncomingGroupCallScreen(
                  data: data,
                  callerName: callerName,
                );
              },
            ),
          ],
        );
      },
    ).whenComplete(() {
      if (_activeForegroundDialogCallId == callId) {
        _activeForegroundDialogCallId = null;
      }
    });
  }

  void _openIncomingGroupCallScreen({
    required Map<String, dynamic> data,
    required String callerName,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
        '[IncomingCallService] Navigator unavailable pour appel groupe',
      );
      _pendingAndroidIncomingIntent = Map<String, dynamic>.from(data);
      return;
    }

    final callId = _parseCallId(
      raw: data['call_id'] ?? data['callId'],
      fallback: '',
    );
    final groupId = _parseUserId(data['group_id'] ?? data['groupId']);
    final isVideo = _isVideoCall(data);
    final groupName =
        _stringFromPayload(data, const ['group_name', 'groupName']) ??
        callerName;

    if (callId.isEmpty) {
      debugPrint('[IncomingCallService] call_id manquant dans appel groupe.');
      return;
    }

    if (_activeForegroundDialogCallId == callId) {
      _activeForegroundDialogCallId = null;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          callId: callId,
          groupId: groupId,
          groupName: groupName,
          isVideo: isVideo,
          isIncoming: true,
        ),
      ),
    );
  }
}
