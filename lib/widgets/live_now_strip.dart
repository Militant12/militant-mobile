import 'package:flutter/material.dart';

import '../screens/live_screen.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'common/common.dart';

/// Bandeau « En direct » en haut du fil : les lives en cours, en défilement
/// horizontal. Il ne prend aucune place quand aucun live n'est en cours ou si
/// le chargement échoue.
class LiveNowStrip extends StatefulWidget {
  const LiveNowStrip({super.key, this.loadLives, this.refreshCount = 0});

  /// Pour les tests ; par défaut `ApiService.fetchActiveLives`.
  final Future<List<Map<String, dynamic>>> Function()? loadLives;

  /// Change à chaque rafraîchissement du fil : les lives sont rechargés, pour
  /// retirer ceux qui sont terminés et montrer ceux qui viennent de commencer.
  final int refreshCount;

  @override
  State<LiveNowStrip> createState() => _LiveNowStripState();
}

class _LiveNowStripState extends State<LiveNowStrip> {
  List<Map<String, dynamic>> _lives = const [];
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LiveNowStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshCount != oldWidget.refreshCount) _load();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> lives;
      if (widget.loadLives != null) {
        lives = await widget.loadLives!();
      } else {
        _api = await ApiService.getInstance();
        lives = await _api!.fetchActiveLives();
      }
      if (mounted) setState(() => _lives = lives);
    } catch (_) {
      // Le fil reste utilisable sans ce bandeau. Les lives déjà affichés sont
      // peut-être terminés : mieux vaut les retirer.
      if (mounted) setState(() => _lives = const []);
    }
  }

  void _open(Map<String, dynamic> live) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveScreen(initialLiveId: live['id'])),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lives.isEmpty) return const SizedBox.shrink();
    final lang = LanguageService.instance;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space8,
              AppTokens.space16,
              AppTokens.space8,
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: colors.primary),
                const SizedBox(width: AppTokens.space8),
                Text(
                  lang.translate('live_tab_discover'),
                  style: context.text.titleSmall,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space16,
              ),
              itemCount: _lives.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppTokens.space8),
              itemBuilder: (context, index) => _buildLive(_lives[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLive(Map<String, dynamic> live) {
    final colors = context.colors;
    final username = live['username']?.toString() ?? '';
    final title = live['title']?.toString() ?? '';
    final avatar = live['avatar']?.toString();
    final label = LanguageService.instance
        .translate('live_now_item')
        .replaceFirst('{user}', username)
        .replaceFirst('{title}', title);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(live),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space8,
              AppTokens.space8,
              AppTokens.space16,
              AppTokens.space8,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: AppAvatar(
                    url: _api?.getImageUrl(avatar) ?? avatar,
                    name: username,
                    radius: 18,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge,
                      ),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: context.tokens.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
