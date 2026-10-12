import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/language_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';

/// Bandeau « Pas de connexion internet » affiché au-dessus de tous les écrans
/// (via `MaterialApp.builder`) tant que l'appareil n'a aucun réseau.
///
/// Il pousse le contenu vers le bas au lieu de le recouvrir, et reprend à son
/// compte la marge de la barre d'état.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    super.key,
    required this.child,
    this.connectivityChanges,
    this.checkConnectivity,
  });

  final Widget child;

  /// Pour les tests ; par défaut `Connectivity().onConnectivityChanged`.
  final Stream<List<ConnectivityResult>>? connectivityChanges;

  /// Pour les tests ; par défaut `Connectivity().checkConnectivity`.
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    final connectivity =
        widget.connectivityChanges == null || widget.checkConnectivity == null
        ? Connectivity()
        : null;
    _subscription =
        (widget.connectivityChanges ?? connectivity!.onConnectivityChanged)
            .listen(_update);
    (widget.checkConnectivity ?? connectivity!.checkConnectivity)()
        .then(_update)
        .catchError((_) {});
  }

  void _update(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _offline
              ? _Banner(topPadding: topPadding)
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: _offline
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: widget.child,
                )
              : widget.child,
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Le bandeau passe sous la barre d'état : on adapte la couleur de ses
    // icônes (heure, batterie) au fond du bandeau.
    final overlayStyle =
        ThemeData.estimateBrightnessForColor(colors.inverseSurface) ==
            Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: colors.inverseSurface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.space16,
              topPadding + AppTokens.space8,
              AppTokens.space16,
              AppTokens.space8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 18,
                  color: colors.onInverseSurface,
                ),
                const SizedBox(width: AppTokens.space8),
                Flexible(
                  child: Text(
                    LanguageService.instance.translate('offline_banner'),
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.onInverseSurface,
                    ),
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
