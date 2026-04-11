import 'package:shared_preferences/shared_preferences.dart';

import '../config/livekit_config.dart';

/// LiveKit URLs resolved at runtime (SharedPreferences overrides + API + compile-time).
class LiveKitRuntimeConfig {
  LiveKitRuntimeConfig._();

  static const String _keyServerUrl = 'livekit_server_url_override';
  static const String _keyTokenEndpoint = 'livekit_token_endpoint_override';

  /// When [useDeviceOverrides] is false, stored technician fields are ignored (standard users).
  static Future<String> effectiveTokenEndpoint({
    bool useDeviceOverrides = true,
  }) async {
    if (useDeviceOverrides) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_keyTokenEndpoint)?.trim() ?? '';
      if (stored.isNotEmpty) {
        return stored;
      }
    }
    return LiveKitConfig.tokenEndpoint.trim();
  }

  static Future<bool> hasEffectiveTokenEndpoint({
    bool useDeviceOverrides = true,
  }) async {
    return (await effectiveTokenEndpoint(useDeviceOverrides: useDeviceOverrides))
        .isNotEmpty;
  }

  /// Priority: user override in prefs → [fromApi] → compile-time [LiveKitConfig.serverUrl].
  static Future<String> effectiveServerUrl({
    String? fromApi,
    bool useDeviceOverrides = true,
  }) async {
    if (useDeviceOverrides) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_keyServerUrl)?.trim() ?? '';
      if (stored.isNotEmpty) {
        return stored;
      }
    }
    final api = fromApi?.trim() ?? '';
    if (api.isNotEmpty) {
      return api;
    }
    return LiveKitConfig.serverUrl.trim();
  }

  static Future<void> setServerUrlOverride(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      await prefs.remove(_keyServerUrl);
    } else {
      await prefs.setString(_keyServerUrl, v);
    }
  }

  static Future<void> setTokenEndpointOverride(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      await prefs.remove(_keyTokenEndpoint);
    } else {
      await prefs.setString(_keyTokenEndpoint, v);
    }
  }

  static Future<String?> getStoredServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyServerUrl)?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  static Future<String?> getStoredTokenEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyTokenEndpoint)?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
