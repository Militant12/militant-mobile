import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<dynamic> _events = [];
  bool _isLoading = false;

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
      setState(() {
        _events.clear();
        _events.addAll(events);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          LanguageService.instance.translate('events_title'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _events.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 64,
                    color: Color(0xFF888888),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LanguageService.instance.translate('no_events'),
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: const Color(0xFFBE1E1E),
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
        backgroundColor: const Color(0xFFBE1E1E),
        child: const Icon(Icons.add, color: Colors.white),
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
    final creatorId = event['creator_id'];

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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFBE1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDay(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getMonth(date),
                    style: const TextStyle(
                      color: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF888888),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(
                              color: Color(0xFF888888),
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
                      style: const TextStyle(
                        color: Color(0xFF888888),
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
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFBE1E1E)),
              title: Text(
                LanguageService.instance.translate('delete'),
                style: const TextStyle(color: Colors.white),
              ),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('delete_event'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('delete_event_confirm'),
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.translate('cancel'),
              style: const TextStyle(color: Color(0xFF888888)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('delete'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiService.getInstance();
        await api.deleteEvent(event['id']);
        setState(() {
          _events.remove(event);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(lang.translate('event_deleted'))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')));
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
