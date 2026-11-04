import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme_context.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';
import '../theme/app_tokens.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  bool _isLoading = true;
  bool _isJoining = false;

  /// Vrai juste après « J'y serai » : le tampon arrive en s'animant.
  bool _stampLanding = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final api = await ApiService.getInstance();
      final event = await api.getEventDetails(widget.eventId);
      if (mounted) {
        setState(() {
          _event = event;
          _error = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_event == null) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      } else {
        // Échec d'un rechargement (après « Participer ») : on garde l'affichage.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, LanguageService.instance)),
          ),
        );
      }
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadEvent();
  }

  Future<void> _toggleParticipation() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    try {
      final api = await ApiService.getInstance();
      final isParticipating =
          _event!['is_participating'] == 1 ||
          _event!['is_participating'] == true;

      if (isParticipating) {
        await api.leaveEvent(widget.eventId);
      } else {
        await api.joinEvent(widget.eventId);
      }
      _stampLanding = !isParticipating;
      await _loadEvent();
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// Pendant l'envoi, le bouton est désactivé et son icône tourne.
  Widget _participationIcon(IconData icon) {
    if (!_isJoining) return Icon(icon, size: 20);
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        color: context.tokens.textMuted,
        strokeWidth: 2,
      ),
    );
  }

  Future<String?> _getImageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    final api = await ApiService.getInstance();
    return api.getImageUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    if (_isLoading) {
      return Scaffold(appBar: AppBar(), body: const AppLoader());
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? ErrorState(error: _error, onRetry: _retry)
            : EmptyState(
                icon: Icons.event_busy_outlined,
                title: lang.translate('event_not_found'),
              ),
      );
    }

    final isParticipating =
        _event!['is_participating'] == 1 || _event!['is_participating'] == true;
    final participantsCount = _event!['participants_count'] ?? 0;
    final coverImage = _event!['cover_image'] ?? _event!['image'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image de couverture
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: context.colors.surface,
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: coverImage != null
                  ? FutureBuilder<String?>(
                      future: _getImageUrl(coverImage),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image(
                            image: CachedNetworkImageProvider(snapshot.data!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholderCover(),
                          );
                        }
                        return _buildPlaceholderCover();
                      },
                    )
                  : _buildPlaceholderCover(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre, et le tampon à côté quand on y va.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _event!['title'] ?? lang.translate('event'),
                          style: context.text.headlineMedium,
                        ),
                      ),
                      if (isParticipating) ...[
                        const SizedBox(width: AppTokens.space12),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Stamp(
                            label: lang.translate('stamp_going'),
                            semanticLabel: lang.translate('stamp_going_status'),
                            animate: _stampLanding,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Organisateur
                  if (_event!['username'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          FutureBuilder<String?>(
                            future: _getImageUrl(_event!['avatar']),
                            builder: (context, snapshot) => AppAvatar(
                              url: snapshot.data,
                              name: _event!['username']?.toString(),
                              radius: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${lang.translate('organized_by')} ',
                            style: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: AppTokens.fontBodyMedium,
                            ),
                          ),
                          Text(
                            _event!['username'],
                            style: TextStyle(
                              color: context.colors.onSurface,
                              fontSize: AppTokens.fontBodyMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bloc Infos Clés (Date & Lieu)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        // Date
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: context.colors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.translate('date_and_time'),
                                    style: TextStyle(
                                      color: context.tokens.textMuted,
                                      fontSize: AppTokens.fontBodySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(_event!['event_date']),
                                    style: TextStyle(
                                      color: context.colors.onSurface,
                                      fontSize: AppTokens.fontBodyLarge,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Lieu
                        if (_event!['location'] != null &&
                            _event!['location'].toString().isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: context.colors.outlineVariant, height: 1),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.colors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: context.colors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.translate('location'),
                                      style: TextStyle(
                                        color: context.tokens.textMuted,
                                        fontSize: AppTokens.fontBodySmall,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _event!['location'],
                                      style: TextStyle(
                                        color: context.colors.onSurface,
                                        fontSize: AppTokens.fontBodyLarge,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Participants
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: context.colors.outlineVariant, height: 1),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.people,
                                color: context.colors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.translate('participants'),
                                    style: TextStyle(
                                      color: context.tokens.textMuted,
                                      fontSize: AppTokens.fontBodySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$participantsCount ${participantsCount > 1 ? lang.translate('participant_count_plural') : lang.translate('participant_count')}',
                                    style: TextStyle(
                                      color: context.colors.onSurface,
                                      fontSize: AppTokens.fontBodyLarge,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // J'y serai / Je n'y vais plus
                  SizedBox(
                    width: double.infinity,
                    child: isParticipating
                        ? OutlinedButton.icon(
                            onPressed: _isJoining ? null : _toggleParticipation,
                            icon: _participationIcon(Icons.event_busy_outlined),
                            label: Text(lang.translate('event_not_going')),
                          )
                        : FilledButton.icon(
                            onPressed: _isJoining ? null : _toggleParticipation,
                            icon: _participationIcon(
                              Icons.event_available_rounded,
                            ),
                            label: Text(lang.translate('event_going')),
                          ),
                  ),

                  const SizedBox(height: 28),

                  // Description
                  if (_event!['description'] != null &&
                      _event!['description'].toString().isNotEmpty) ...[
                    Text(
                      lang.translate('about_event'),
                      style: TextStyle(
                        color: context.colors.onSurface,
                        fontSize: AppTokens.fontTitleLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.outlineVariant),
                      ),
                      child: Text(
                        _event!['description'],
                        style: TextStyle(
                          color: context.colors.onSurface.withValues(alpha: 0.8),
                          fontSize: AppTokens.fontBodyLarge,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surfaceContainerHigh, context.colors.surface],
        ),
      ),
      child: Center(
        child: Icon(Icons.event, size: 64, color: context.colors.outline),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    final lang = LanguageService.instance;
    if (dateStr == null) return lang.translate('unknown_date');
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final months = [
        lang.translate('january'),
        lang.translate('february'),
        lang.translate('march'),
        lang.translate('april'),
        lang.translate('may'),
        lang.translate('june'),
        lang.translate('july'),
        lang.translate('august'),
        lang.translate('september'),
        lang.translate('october'),
        lang.translate('november'),
        lang.translate('december'),
      ];
      final days = [
        lang.translate('monday'),
        lang.translate('tuesday'),
        lang.translate('wednesday'),
        lang.translate('thursday'),
        lang.translate('friday'),
        lang.translate('saturday'),
        lang.translate('sunday'),
      ];

      final dayName = days[date.weekday - 1];
      final monthName = months[date.month - 1];

      return '$dayName ${date.day} $monthName ${date.year} ${lang.translate('date_at')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
