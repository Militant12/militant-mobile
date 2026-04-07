import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../services/user_status_service.dart';

/// Chip cliquable affichant ton propre statut sur ton profil
class StatusChip extends StatelessWidget {
  final UserStatus status;
  final VoidCallback? onTap;

  const StatusChip({super.key, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final preset = UserStatusService.instance.currentPreset;

    if (status.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.circlePlus,
                  size: 11, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                'Ajouter un statut',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: preset?.gradient != null
              ? LinearGradient(
                  colors: (preset!.gradient as LinearGradient)
                      .colors
                      .map((c) => c.withOpacity(0.3))
                      .toList(),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: preset?.gradient == null
              ? (preset?.color ?? Colors.white).withOpacity(0.15)
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: (preset?.color ?? Colors.white).withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preset != null) ...[
              FaIcon(preset.icon, size: 11, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              status.label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet pour choisir un statut
class StatusPickerDialog extends StatefulWidget {
  final UserStatus initialStatus;
  final ApiService api;

  const StatusPickerDialog(
      {super.key, required this.initialStatus, required this.api});

  static Future<void> show(BuildContext context, ApiService api) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusPickerDialog(
        initialStatus: UserStatusService.instance.value,
        api: api,
      ),
    );
  }

  @override
  State<StatusPickerDialog> createState() => _StatusPickerDialogState();
}

class _StatusPickerDialogState extends State<StatusPickerDialog> {
  late TextEditingController _textCtrl;
  PresetStatus? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = UserStatusService.instance.currentPreset;
    _textCtrl = TextEditingController(
      text: _selected == null ? widget.initialStatus.label : '',
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await UserStatusService.instance
        .setStatus(_selected, _textCtrl.text, widget.api);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    await UserStatusService.instance.clearStatus(widget.api);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accent = const Color(0xFFBE1E1E);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Titre
          Row(children: [
            FaIcon(FontAwesomeIcons.circleUser, color: accent, size: 18),
            const SizedBox(width: 10),
            Text('Mon statut militant',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),

          // Grille de statuts prédéfinis
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kPresetStatuses.map((p) {
              final isSelected = _selected?.key == p.key;
              return GestureDetector(
                onTap: () => setState(() {
                  _selected = isSelected ? null : p;
                  if (!isSelected) _textCtrl.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected && p.gradient != null ? p.gradient : null,
                    color: isSelected && p.gradient == null
                        ? p.color.withOpacity(0.18)
                        : (!isSelected ? theme.colorScheme.surface : null),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? p.color : theme.dividerColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: p.color.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(p.icon,
                          size: 13,
                          color: isSelected ? Colors.white : theme.hintColor),
                      const SizedBox(width: 7),
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 8),

          // Statut personnalisé libre
          TextField(
            controller: _textCtrl,
            maxLength: 60,
            onChanged: (_) => setState(() => _selected = null),
            decoration: InputDecoration(
              hintText: 'Ou écris ton propre statut…',
              counterText: '',
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: FaIcon(FontAwesomeIcons.penToSquare,
                    size: 14, color: Colors.grey),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Boutons
          Row(
            children: [
              // Effacer
              OutlinedButton.icon(
                onPressed: _saving ? null : _clear,
                icon: const FaIcon(FontAwesomeIcons.trash, size: 12),
                label: const Text('Effacer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const FaIcon(FontAwesomeIcons.check, size: 13),
                  label: const Text('Enregistrer'),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge statut en lecture seule pour voir le statut d'un autre utilisateur
class UserStatusBadge extends StatelessWidget {
  final String? statusEmoji; // contient en fait la key du preset
  final String? statusText;

  const UserStatusBadge({super.key, this.statusEmoji, this.statusText});

  bool get _hasStatus =>
      (statusText != null && statusText!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasStatus) return const SizedBox.shrink();

    // Retrouver l'icône FontAwesome via la key
    PresetStatus? preset;
    if (statusEmoji != null && statusEmoji!.isNotEmpty) {
      try {
        preset = kPresetStatuses.firstWhere((p) => p.key == statusEmoji);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: preset?.gradient,
        color: preset?.gradient == null
            ? (preset?.color ?? Theme.of(context).colorScheme.primary).withOpacity(0.12)
            : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (preset?.color ?? Theme.of(context).colorScheme.primary).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (preset != null) ...[
            FaIcon(preset.icon, size: 11,
                color: preset.gradient != null ? Colors.white : preset.color),
            const SizedBox(width: 6),
          ],
          Text(
            statusText!,
            style: TextStyle(
              fontSize: 12,
              color: preset?.gradient != null
                  ? Colors.white
                  : (preset?.color ?? Theme.of(context).colorScheme.onSurfaceVariant),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
