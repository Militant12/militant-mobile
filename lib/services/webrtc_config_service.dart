import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

class WebRtcConfigService {
  WebRtcConfigService._();

  static List<Map<String, dynamic>>? _cachedIceServers;
  static DateTime? _lastFetchAt;

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const bool _preferRelayOnMobileNetwork = true;
  static const bool _preferUdpTurnOnMobileNetwork = true;

  static const List<Map<String, dynamic>> _defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
  ];

  static Future<Map<String, dynamic>> buildRtcConfiguration(
    ApiService apiService,
  ) async {
    final baseIceServers = await _loadIceServers(apiService);
    final connectivity = await Connectivity().checkConnectivity();
    final isMobileNetwork = connectivity.contains(ConnectivityResult.mobile);
    final hasRelayCapableServer = baseIceServers.any((server) {
      final urls = server['urls'];
      if (urls is String) {
        return urls.startsWith('turn:') || urls.startsWith('turns:');
      }
      if (urls is List) {
        return urls.any(
          (url) =>
              url is String &&
              (url.startsWith('turn:') || url.startsWith('turns:')),
        );
      }
      return false;
    });

    final shouldPreferRelay =
        _preferRelayOnMobileNetwork && isMobileNetwork && hasRelayCapableServer;
    final iceServers = _preferUdpTurnOnMobileNetwork && shouldPreferRelay
        ? _preferUdpTurnOnly(baseIceServers)
        : baseIceServers;

    final relayStillAvailable = iceServers.any((server) {
      final urls = server['urls'];
      if (urls is String) {
        return urls.startsWith('turn:') || urls.startsWith('turns:');
      }
      if (urls is List) {
        return urls.any(
          (url) =>
              url is String &&
              (url.startsWith('turn:') || url.startsWith('turns:')),
        );
      }
      return false;
    });

    // Mobile networks are the least predictable for NAT traversal. When a TURN
    // relay is available, we force relay mode there to make 5G <-> Wi-Fi calls
    // and handovers much more reliable.
    final iceTransportPolicy = shouldPreferRelay && relayStillAvailable
        ? 'relay'
        : 'all';

    debugPrint(
      '[WebRTC][config] network=$connectivity mobile=$isMobileNetwork relay_capable=$hasRelayCapableServer force_relay=$shouldPreferRelay policy=$iceTransportPolicy servers=${_describeIceServers(iceServers)}',
    );

    return {
      'iceServers': iceServers,
      'iceTransportPolicy': iceTransportPolicy,
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'sdpSemantics': 'unified-plan',
      'iceCandidatePoolSize': 8,
    };
  }

  static Future<List<Map<String, dynamic>>> _loadIceServers(
    ApiService apiService,
  ) async {
    final now = DateTime.now();
    if (_cachedIceServers != null &&
        _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < _cacheDuration) {
      return _cachedIceServers!;
    }

    try {
      final settings = await apiService.getServerSettings();
      debugPrint(
        '[WebRTC][settings] mode=${settings['turn_credentials_mode']} ttl=${settings['turn_credentials_ttl']} turn_servers=${settings['turn_servers']}',
      );
      final collected = <Map<String, dynamic>>[
        ..._defaultIceServers,
        ..._extractIceServers(settings['webrtc_ice_servers']),
        ..._extractIceServers(settings['ice_servers']),
        ..._extractIceServers(settings['stun_servers']),
        ..._extractIceServers(settings['turn_servers']),
      ];

      _cachedIceServers = _dedupeIceServers(collected);
      _lastFetchAt = now;
      return _cachedIceServers!;
    } catch (_) {
      _cachedIceServers = _defaultIceServers;
      _lastFetchAt = now;
      debugPrint('[WebRTC][settings] fallback to default STUN servers only');
      return _cachedIceServers!;
    }
  }

  static String _describeIceServers(List<Map<String, dynamic>> servers) {
    return servers
        .map((server) {
          final urls = server['urls'];
          final username = server['username'];
          return username == null ? '$urls' : '$urls@$username';
        })
        .join(', ');
  }

  static List<Map<String, dynamic>> _extractIceServers(dynamic raw) {
    if (raw is! List) return const [];

    final servers = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is String && entry.trim().isNotEmpty) {
        servers.add({'urls': entry.trim()});
        continue;
      }
      if (entry is! Map) continue;

      final urls = entry['urls'] ?? entry['url'];
      if (urls == null) continue;

      final server = <String, dynamic>{'urls': urls};
      final username = entry['username'];
      final credential = entry['credential'] ?? entry['password'];
      if (username != null) server['username'] = username;
      if (credential != null) server['credential'] = credential;
      servers.add(server);
    }

    return servers;
  }

  static List<Map<String, dynamic>> _dedupeIceServers(
    List<Map<String, dynamic>> servers,
  ) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final server in servers) {
      final key =
          '${server['urls']}|${server['username'] ?? ''}|${server['credential'] ?? ''}';
      if (seen.add(key)) {
        deduped.add(server);
      }
    }

    return deduped;
  }

  static List<Map<String, dynamic>> _preferUdpTurnOnly(
    List<Map<String, dynamic>> servers,
  ) {
    final stunServers = <Map<String, dynamic>>[];
    final udpTurnServers = <Map<String, dynamic>>[];

    for (final server in servers) {
      final urls = server['urls'];
      final urlList = urls is List
          ? urls.whereType<String>().toList()
          : <String>[if (urls is String) urls];

      final hasTurnUrl = urlList.any(
        (url) => url.startsWith('turn:') || url.startsWith('turns:'),
      );
      final hasUdpTurnUrl = urlList.any(
        (url) => url.startsWith('turn:') && url.contains('transport=udp'),
      );

      if (!hasTurnUrl) {
        stunServers.add(server);
        continue;
      }

      if (hasUdpTurnUrl) {
        final filteredUrls = urlList
            .where(
              (url) => url.startsWith('turn:') && url.contains('transport=udp'),
            )
            .toList();
        final filteredServer = Map<String, dynamic>.from(server);
        filteredServer['urls'] = filteredUrls.length == 1
            ? filteredUrls.first
            : filteredUrls;
        udpTurnServers.add(filteredServer);
      }
    }

    if (udpTurnServers.isNotEmpty) {
      debugPrint(
        '[WebRTC][config] forcing TURN udp only for diagnostics: ${_describeIceServers(udpTurnServers)}',
      );
      return [...stunServers, ...udpTurnServers];
    }

    return servers;
  }
}
