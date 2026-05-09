import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _imagePath;
  bool _isSubmitting = false;
  bool _hasDraft = false;
  Timer? _draftDebounce;

  static const _draftTitleKey = 'draft_event_title';
  static const _draftDescriptionKey = 'draft_event_description';
  static const _draftLocationKey = 'draft_event_location';
  static const _draftDateKey = 'draft_event_date';
  static const _draftTimeKey = 'draft_event_time';
  static const _draftImageKey = 'draft_event_image';

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleDraftSave);
    _descriptionController.addListener(_scheduleDraftSave);
    _locationController.addListener(_scheduleDraftSave);
    _loadDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _titleController.removeListener(_scheduleDraftSave);
    _descriptionController.removeListener(_scheduleDraftSave);
    _locationController.removeListener(_scheduleDraftSave);
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _hasDraftContent =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty ||
      _selectedDate != null ||
      _selectedTime != null ||
      _imagePath != null;

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_draftTitleKey) ?? '';
    final description = prefs.getString(_draftDescriptionKey) ?? '';
    final location = prefs.getString(_draftLocationKey) ?? '';
    final dateValue = prefs.getInt(_draftDateKey);
    final timeValue = prefs.getString(_draftTimeKey);
    final imagePath = prefs.getString(_draftImageKey);

    DateTime? date;
    if (dateValue != null) {
      date = DateTime.fromMillisecondsSinceEpoch(dateValue);
    }

    TimeOfDay? time;
    if (timeValue != null && timeValue.contains(':')) {
      final parts = timeValue.split(':');
      final hour = int.tryParse(parts.first);
      final minute = int.tryParse(parts.last);
      if (hour != null && minute != null) {
        time = TimeOfDay(hour: hour, minute: minute);
      }
    }

    if (!mounted) return;
    _titleController.text = title;
    _descriptionController.text = description;
    _locationController.text = location;
    setState(() {
      _selectedDate = date;
      _selectedTime = time;
      _imagePath = imagePath != null && File(imagePath).existsSync()
          ? imagePath
          : null;
      _hasDraft = _hasDraftContent;
    });
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 350), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_hasDraftContent) {
      await _removeDraft(prefs);
      if (mounted && _hasDraft) {
        setState(() => _hasDraft = false);
      }
      return;
    }

    await prefs.setString(_draftTitleKey, _titleController.text);
    await prefs.setString(_draftDescriptionKey, _descriptionController.text);
    await prefs.setString(_draftLocationKey, _locationController.text);

    if (_selectedDate == null) {
      await prefs.remove(_draftDateKey);
    } else {
      await prefs.setInt(
        _draftDateKey,
        DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        ).millisecondsSinceEpoch,
      );
    }

    if (_selectedTime == null) {
      await prefs.remove(_draftTimeKey);
    } else {
      await prefs.setString(
        _draftTimeKey,
        '${_selectedTime!.hour}:${_selectedTime!.minute}',
      );
    }

    if (_imagePath == null) {
      await prefs.remove(_draftImageKey);
    } else {
      await prefs.setString(_draftImageKey, _imagePath!);
    }

    if (mounted && !_hasDraft) {
      setState(() => _hasDraft = true);
    }
  }

  Future<void> _removeDraft([SharedPreferences? prefs]) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    await storage.remove(_draftTitleKey);
    await storage.remove(_draftDescriptionKey);
    await storage.remove(_draftLocationKey);
    await storage.remove(_draftDateKey);
    await storage.remove(_draftTimeKey);
    await storage.remove(_draftImageKey);
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    await _removeDraft();
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    if (mounted) {
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _imagePath = null;
        _hasDraft = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
      _scheduleDraftSave();
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFBE1E1E),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _scheduleDraftSave();
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFBE1E1E),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
      _scheduleDraftSave();
    }
  }

  Future<void> _submit() async {
    final lang = LanguageService.instance;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.translate('date_required'))));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = await ApiService.getInstance();

      // Combiner date et heure
      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime?.hour ?? 0,
        _selectedTime?.minute ?? 0,
      );

      String? imageUrl;
      if (_imagePath != null) {
        imageUrl = await api.uploadFile(_imagePath!, type: 'event');
      }

      // Format MySQL: YYYY-MM-DD HH:MM:SS
      final formattedDate =
          '${eventDateTime.year}-${eventDateTime.month.toString().padLeft(2, '0')}-${eventDateTime.day.toString().padLeft(2, '0')} ${eventDateTime.hour.toString().padLeft(2, '0')}:${eventDateTime.minute.toString().padLeft(2, '0')}:00';

      await api.createEvent(
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        eventDate: formattedDate,
        image: imageUrl,
      );

      _draftDebounce?.cancel();
      await _removeDraft();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('event_created'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_loading')}: ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('create_event_title'),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFBE1E1E),
                    ),
                  )
                : Text(
                    lang.translate('create'),
                    style: const TextStyle(
                      color: Color(0xFFBE1E1E),
                      fontSize: 16,
                    ),
                  ),
          ),
          if (_hasDraft)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              onPressed: _isSubmitting ? null : _clearDraft,
              tooltip: lang.translate('clear_draft'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image
            if (_imagePath != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_imagePath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(
                          Icons.image,
                          size: 64,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() => _imagePath = null);
                        _scheduleDraftSave();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              )
            else
              InkWell(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.translate('add_image'),
                        style: const TextStyle(color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Titre
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: lang.translate('event_title_label'),
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return lang.translate('title_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: lang.translate('event_description_label'),
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lieu
            TextFormField(
              controller: _locationController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: lang.translate('event_location_label'),
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                prefixIcon: const Icon(
                  Icons.location_on,
                  color: Color(0xFF888888),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF888888)),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? lang.translate('select_date')
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: TextStyle(
                        color: _selectedDate == null
                            ? const Color(0xFF888888)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Heure
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFF888888)),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime == null
                          ? lang.translate('select_time')
                          : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: _selectedTime == null
                            ? const Color(0xFF888888)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
