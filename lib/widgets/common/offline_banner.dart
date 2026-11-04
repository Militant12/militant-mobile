import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../services/language_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';

enum _Connection { online, offline, backOnline }

/// Bandeau « Pas de connexion internet » affiché au-dessus de tous les écrans
/// (via `MaterialApp.builder`) tant que l'appareil n'a aucun réseau. Au retour
/// du réseau, il dit « De nouveau en ligne » pendant [backOnlineDuration],
/// puis se replie.
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

  static const Duration backOnlineDuration = Duration(seconds: 2);

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _backOnlineTimer;
  _Connection _connection = _Connection.online;

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
    if (!mounted) return;
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    final lang = LanguageService.instance;
    if (offline && _connection != _Connection.offline) {
      _backOnlineTimer?.cancel();
      setState(() => _connection = _Connection.offline);
      _announce(lang.translate('offline_banner'));
    } else if (!offline && _connection == _Connection.offline) {
      setState(() => _connection = _Connection.backOnline);
      _announce(lang.translate('online_again'));
      _backOnlineTimer = Timer(OfflineBanner.backOnlineDuration, () {
        if (mounted) setState(() => _connection = _Connection.online);
      });
    }
  }

  void _announce(String message) {
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      message,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final visible = _connection != _Connection.online;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: visible
              ? _Banner(
                  topPadding: topPadding,
                  backOnline: _connection == _Connection.backOnline,
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: visible
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
  const _Banner({required this.topPadding, required this.backOnline});

  final double topPadding;
  final bool backOnline;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    // Hors ligne : le noir du logo. De retour : la couleur du succès.
    final background = backOnline ? context.tokens.success : AppColors.noir;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final foreground = isDarkBackground ? Colors.white : AppColors.noir;
    // Le bandeau passe sous la barre d'état : on adapte la couleur de ses
    // icônes (heure, batterie) au fond du bandeau.
    final overlayStyle = isDarkBackground
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      // Annoncé par _announce : pas de liveRegion, pour ne pas le lire deux
      // fois sur Android.
      child: Semantics(
        container: true,
        child: Material(
          color: background,
          child: CustomPaint(
            painter: backOnline ? null : const _DiagonalHatch(),
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
                    backOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Flexible(
                    child: Text(
                      lang.translate(
                        backOnline ? 'online_again' : 'offline_banner',
                      ),
                      style: context.text.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
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

/// Bandes à 45°, parallèles à la diagonale du logo, en blanc à 6 %.
class _DiagonalHatch extends CustomPainter {
  const _DiagonalHatch();

  static const double _gap = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 3;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Chaque trait va du bas-gauche vers le haut-droite.
    for (var x = -size.height; x < size.width; x += _gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalHatch oldDelegate) => false;
}
