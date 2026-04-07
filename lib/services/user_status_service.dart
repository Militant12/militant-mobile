import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Statut personnalisé d'un utilisateur militant
class UserStatus {
  final String key;   // clé unique du statut (pour stockage)
  final String label; // texte affiché

  const UserStatus({required this.key, required this.label});

  bool get isEmpty => key.isEmpty && label.isEmpty;

  factory UserStatus.empty() => const UserStatus(key: '', label: '');

  factory UserStatus.fromPrefs(String key, String label) =>
      UserStatus(key: key, label: label);
}

/// Définition d'un statut prédéfini avec icône FontAwesome
class PresetStatus {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Gradient? gradient; // optionnel : remplace la couleur pleine

  const PresetStatus({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.gradient,
  });
}

const List<PresetStatus> kPresetStatuses = [
  PresetStatus(
    key: 'manif',
    label: 'En manif',
    icon: FontAwesomeIcons.fistRaised,
    color: Color(0xFFBE1E1E),
  ),
  PresetStatus(
    key: 'action',
    label: 'En action',
    icon: FontAwesomeIcons.flag,
    color: Color(0xFFBE1E1E),
  ),
  PresetStatus(
    key: 'reunion',
    label: 'En réunion',
    icon: FontAwesomeIcons.users,
    color: Color(0xFFBE1E1E),
    gradient: LinearGradient(
      colors: [Color(0xFFBE1E1E), Color(0xFF1A0000)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  ),
  PresetStatus(
    key: 'dnd',
    label: 'Ne pas déranger',
    icon: FontAwesomeIcons.volumeXmark,
    color: Color(0xFF888888),
  ),
  PresetStatus(
    key: 'formation',
    label: 'En formation',
    icon: FontAwesomeIcons.book,
    color: Color.fromARGB(255, 132, 0, 255),
  ),
  PresetStatus(
    key: 'dispo',
    label: 'Disponible',
    icon: FontAwesomeIcons.circleCheck,
    color: Color(0xFF27AE60),
  ),
  PresetStatus(
    key: 'solidarite',
    label: 'Solidarité',
    icon: FontAwesomeIcons.handshake,
    color: Color(0xFFE67E22),
  ),
  PresetStatus(
    key: 'greve',
    label: 'En grève',
    icon: FontAwesomeIcons.personDigging,
    color: Color(0xFFBE1E1E),
  ),
  PresetStatus(
    key: 'terrain',
    label: 'Sur le terrain',
    icon: FontAwesomeIcons.locationDot,
    color: Color(0xFF2ECC71),
  ),
  PresetStatus(
    key: 'repos',
    label: 'Repos militant',
    icon: FontAwesomeIcons.moon,
    color: Color(0xFF9B59B6),
  ),
  PresetStatus(
    key: 'info',
    label: 'Partage d\'infos',
    icon: FontAwesomeIcons.bullhorn,
    color: Color(0xFFE74C3C),
  ),
  PresetStatus(
    key: 'prison',
    label: 'Soutien prisonnier',
    icon: FontAwesomeIcons.scaleBalanced,
    color: Color(0xFF555555),
  ),
];

/// Service singleton pour le statut utilisateur
class UserStatusService extends ValueNotifier<UserStatus> {
  static final UserStatusService instance = UserStatusService._();

  UserStatusService._() : super(UserStatus.empty());

  static const _keyKey = 'user_status_key';
  static const _keyLabel = 'user_status_label';

  /// Charge le statut depuis SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyKey) ?? '';
    final label = prefs.getString(_keyLabel) ?? '';
    value = UserStatus(key: key, label: label);
  }

  /// Met à jour le statut localement ET sur le serveur
  Future<void> setStatus(PresetStatus? preset, String customLabel, ApiService api) async {
    final key = preset?.key ?? 'custom';
    final label = preset != null ? preset.label : customLabel.trim();

    // 1. Sauvegarder localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKey, key);
    await prefs.setString(_keyLabel, label);
    value = UserStatus(key: key, label: label);

    // 2. Synchroniser avec le serveur (best-effort)
    // On stocke l'icone-key dans status_emoji et le label dans status_text
    try {
      await api.updateUserProfile(
        statusEmoji: key.isEmpty ? null : key,
        statusText: label.isEmpty ? null : label,
        clearStatus: key.isEmpty && label.isEmpty,
      );
    } catch (_) {}
  }

  /// Efface le statut
  Future<void> clearStatus(ApiService api) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyKey);
    await prefs.remove(_keyLabel);
    value = UserStatus.empty();
    try {
      await api.updateUserProfile(clearStatus: true);
    } catch (_) {}
  }

  /// Retourne le PresetStatus correspondant à la clé en mémoire (ou null)
  PresetStatus? get currentPreset {
    if (value.isEmpty) return null;
    try {
      return kPresetStatuses.firstWhere((p) => p.key == value.key);
    } catch (_) {
      return null;
    }
  }
}
