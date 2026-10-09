import 'package:flutter/material.dart';
import '../theme/theme_context.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<dynamic> _events = [];
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final events = await api.getEvents();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.instance.translate('events_title')),
      ),
      body: _isLoading && _events.isEmpty
          ? const SkeletonList()
          : _error != null && _events.isEmpty
          ? ErrorState(error: _error, onRetry: _loadEvents)
          : _events.isEmpty
          ? EmptyState(
              icon: Icons.event_outlined,
              title: LanguageService.instance.translate('no_events'),
            )
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: context.colors.primary,
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return _buildEventItem(event);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (result == true) {
            _loadEvents();
          }
        },
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        tooltip: LanguageService.instance.translate('create_event'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventItem(dynamic event) {
    final lang = LanguageService.instance;
    final title = event['title'] ?? lang.translate('event');
    final description = event['description'] ?? '';
    final date = event['event_date'] ?? '';
    final location = event['location'] ?? '';
    final eventId = event['id'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: eventId),
          ),
        );
      },
      onLongPress: () => _showEventOptions(event),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDay(date),
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getMonth(date),
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontSize: 11,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: context.tokens.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tokens.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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

  String _getDay(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      return date.day.toString();
    } catch (e) {
      return '?';
    }
  }

  String _getMonth(String dateStr) {
    try {
      final lang = LanguageService.instance;
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final months = [
        lang.translate('month_jan'),
        lang.translate('month_feb'),
        lang.translate('month_mar'),
        lang.translate('month_apr'),
        lang.translate('month_may'),
        lang.translate('month_jun'),
        lang.translate('month_jul'),
        lang.translate('month_aug'),
        lang.translate('month_sep'),
        lang.translate('month_oct'),
        lang.translate('month_nov'),
        lang.translate('month_dec'),
      ];
      return months[date.month - 1];
    } catch (e) {
      return '?';
    }
  }
}
