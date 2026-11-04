import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/theme_context.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';
import '../theme/app_tokens.dart';
import '../utils/event_dates.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.loadEvents});

  /// Pour les tests ; par défaut `ApiService.getEvents`.
  final Future<List<dynamic>> Function()? loadEvents;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<dynamic> _events = [];
  bool _isLoading = false;
  Object? _error;

  /// Événements dont la réponse « J'y serai » est en cours d'envoi.
  final Set<int> _pending = {};

  /// Événements rejoints à l'instant : leur tampon arrive en s'animant.
  final Set<int> _justJoined = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = widget.loadEvents != null
          ? await widget.loadEvents!()
          : await (await ApiService.getInstance()).getEvents();
      if (!mounted) return;
      setState(() {
        _error = null;
        _events.clear();
        _events.addAll(events);
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      if (!mounted) return;
      if (_events.isEmpty) {
        setState(() => _error = e);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, LanguageService.instance))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _createEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateEventScreen()),
    );
    if (result == true) {
      _loadEvents();
    }
  }
  static int? _eventId(dynamic event) => int.tryParse('${event['id']}');

  static bool _isGoing(dynamic event) {
    final value = event['is_participating'];
    return value == true || value == 1 || value == '1';
  }

  static int _goingCount(dynamic event) =>
      int.tryParse('${event['participants_count'] ?? 0}') ?? 0;

  /// « J'y serai » / « Je n'y vais plus » depuis la liste : affiché tout de
  /// suite, annulé avec un message si la requête échoue.
  Future<void> _toggleParticipation(dynamic event) async {
    final id = _eventId(event);
    if (id == null || _pending.contains(id)) return;
    final wasGoing = _isGoing(event);
    final previousCount = event['participants_count'];
    setState(() {
      _pending.add(id);
      event['is_participating'] = wasGoing ? 0 : 1;
      final count = _goingCount(event) + (wasGoing ? -1 : 1);
      event['participants_count'] = count < 0 ? 0 : count;
      if (wasGoing) {
        _justJoined.remove(id);
      } else {
        _justJoined.add(id);
      }
    });
    try {
      final api = await ApiService.getInstance();
      if (wasGoing) {
        await api.leaveEvent(id);
      } else {
        await api.joinEvent(id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        event['is_participating'] = wasGoing ? 1 : 0;
        event['participants_count'] = previousCount;
        _justJoined.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getFriendlyErrorMessage(e, LanguageService.instance)),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  void _shareEvent(dynamic event) {
    final date = EventDates.parse(event['event_date']);
    final location = '${event['location'] ?? ''}'.trim();
    Share.share(
      [
        '${event['title'] ?? ''}'.trim(),
        if (date != null) '${EventDates.day(date)} · ${EventDates.time(date)}',
        if (location.isNotEmpty) location,
      ].where((line) => line.isNotEmpty).join('\n'),
    );
  }

  /// Les événements (déjà triés par date par l'API), précédés d'un intitulé
  /// à chaque nouveau jour.
  List<Object> _entries() {
    final entries = <Object>[];
    DateTime? lastDay;
    for (final event in _events) {
      final date = EventDates.parse(event['event_date']);
      if (date != null &&
          (lastDay == null || !EventDates.sameDay(lastDay, date))) {
        entries.add(date);
        lastDay = date;
      }
      entries.add(event);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.instance.translate('agenda_title')),
        titleTextStyle: context.text.headlineMedium,
        centerTitle: false,
      ),
      body: _isLoading && _events.isEmpty
          ? const SkeletonList()
          : _error != null && _events.isEmpty
          ? ErrorState(error: _error, onRetry: _loadEvents)
          : _events.isEmpty
          ? EmptyState(
              icon: Icons.event_outlined,
              title: LanguageService.instance.translate('no_events'),
              action: FilledButton.icon(
                onPressed: _createEvent,
                icon: const Icon(Icons.add),
                label: Text(LanguageService.instance.translate('create_event')),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: context.colors.primary,
              child: Builder(
                builder: (context) {
                  final entries = _entries();
                  return ListView.builder(
                    // Place pour le bouton flottant sous la dernière carte.
                    padding: const EdgeInsets.only(
                      top: AppTokens.space4,
                      bottom: 88,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return entry is DateTime
                          ? _buildDayHeader(entry)
                          : _buildEventItem(entry);
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        tooltip: LanguageService.instance.translate('create_event'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDayHeader(DateTime day) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space16,
        AppTokens.space16,
        AppTokens.space4,
      ),
      child: Semantics(
        header: true,
        child: Text(
          EventDates.day(day).toUpperCase(),
          style: context.eyebrow.copyWith(color: context.tokens.textMuted),
        ),
      ),
    );
  }

  Widget _buildEventItem(dynamic event) {
    final lang = LanguageService.instance;
    final muted = context.tokens.textMuted;
    final id = _eventId(event);
    final title = event['title'] ?? lang.translate('event');
    final location = '${event['location'] ?? ''}'.trim();
    final date = EventDates.parse(event['event_date']);
    final going = _isGoing(event);
    final count = _goingCount(event);
    final pending = id != null && _pending.contains(id);
    final meta = [
      if (date != null) EventDates.time(date),
      if (location.isNotEmpty) location,
    ].join(' · ');
    final countText = switch (count) {
      0 => lang.translate('event_nobody_going'),
      1 => lang.translate('event_person_going'),
      _ => lang
          .translate('event_people_going')
          .replaceAll('{count}', '$count'),
    };

    return Padding(
      key: ValueKey('event-${event['id']}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12 / 2,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: id == null
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(eventId: id),
                    ),
                  );
                  // La participation a pu changer sur la page de détail.
                  if (mounted) _loadEvents();
                },
          onLongPress: () => _showEventOptions(event),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date != null) ...[
                      _EventDateBlock(date: date),
                      const SizedBox(width: AppTokens.space12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium,
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: AppTokens.space4),
                            Text(
                              meta,
                              style: context.text.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            countText,
                            style: context.text.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Le tampon se pose à côté du titre, jamais par-dessus.
                    if (going) ...[
                      const SizedBox(width: AppTokens.space8),
                      Stamp(
                        label: lang.translate('stamp_going'),
                        semanticLabel: lang.translate('stamp_going_status'),
                        // Une seule fois : pas de nouvelle arrivée quand la
                        // carte est reconstruite.
                        animate: id != null && _justJoined.remove(id),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTokens.space12),
                Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space8,
                  children: [
                    if (going)
                      OutlinedButton.icon(
                        onPressed: pending
                            ? null
                            : () => _toggleParticipation(event),
                        icon: const Icon(Icons.event_busy_outlined, size: 20),
                        label: Text(lang.translate('event_not_going')),
                      )
                    else
                      FilledButton.icon(
                        onPressed: pending
                            ? null
                            : () => _toggleParticipation(event),
                        icon: const Icon(
                          Icons.event_available_rounded,
                          size: 20,
                        ),
                        label: Text(lang.translate('event_going')),
                      ),
                    OutlinedButton(
                      onPressed: () => _shareEvent(event),
                      child: Text(lang.translate('share')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventOptions(dynamic event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: context.colors.primary),
              title: Text(LanguageService.instance.translate('delete')),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(event);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(dynamic event) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('delete_event')),
        content: Text(
          lang.translate('delete_event_confirm'),
          style: TextStyle(color: context.tokens.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.translate('cancel'),
              style: TextStyle(color: context.tokens.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('delete'),
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiService.getInstance();
        await api.deleteEvent(event['id']);
        if (!mounted) return;
        setState(() {
          _events.remove(event);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.translate('event_deleted'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(getFriendlyErrorMessage(e, lang)),
            ),
          );
        }
      }
    }
  }
}

/// Le jour et le mois sur fond brand-soft, en tête de la carte.
class _EventDateBlock extends StatelessWidget {
  const _EventDateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onPrimaryContainer;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: Column(
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: context.text.headlineSmall?.copyWith(
              color: ink,
              height: 1.1,
            ),
          ),
          Text(
            EventDates.monthShort(date),
            style: context.eyebrow.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}
