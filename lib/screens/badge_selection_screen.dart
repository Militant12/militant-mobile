import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/militant_badge.dart';

class BadgeSelectionScreen extends StatefulWidget {
  const BadgeSelectionScreen({super.key});

  @override
  State<BadgeSelectionScreen> createState() => _BadgeSelectionScreenState();
}

class _BadgeSelectionScreenState extends State<BadgeSelectionScreen> {
  String? _selectedBadge;
  String? _currentBadge;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, String>> _badges = [
    {'id': 'militant', 'name': 'Militant'},
    {'id': 'antifa', 'name': 'Antifa'},
    {'id': 'anarchist', 'name': 'Anarchiste'},
    {'id': 'cnt-ait', 'name': 'CNT-AIT'},
    {'id': 'cnt-f', 'name': 'CNT-F'},
    {'id': 'cnt-so', 'name': 'CNT-SO'},
    {'id': 'fa', 'name': 'FA'},
    {'id': 'ocl', 'name': 'OCL'},
    {'id': 'cga', 'name': 'CGA'},
    {'id': 'ucl', 'name': 'UCL'},
    {'id': 'fll', 'name': 'FLL'},
    {'id': 'slm', 'name': 'SLM'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentBadge();
  }

  Future<void> _loadCurrentBadge() async {
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();
      setState(() {
        _currentBadge = profile['militant_badge'];
        _selectedBadge = _currentBadge;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveBadge() async {
    if (_selectedBadge == _currentBadge) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = await ApiService.getInstance();
      await api.updateMilitantBadge(_selectedBadge);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge mis à jour avec succès')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(lang.translate('my_militant_badge')),
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _saveBadge,
              child: Text(
                lang.translate('save'),
                style: const TextStyle(color: Color(0xFFBE1E1E)),
              ),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFBE1E1E),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  lang.translate('select_badge_text'),
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // Option "Aucun badge"
                _buildBadgeOption(
                  id: null,
                  name: lang.translate('no_badge'),
                  isDark: isDark,
                ),
                const Divider(),
                // Liste des badges
                ..._badges.map((badge) => _buildBadgeOption(
                      id: badge['id'],
                      name: badge['name']!,
                      isDark: isDark,
                    )),
              ],
            ),
    );
  }

  Widget _buildBadgeOption({
    required String? id,
    required String name,
    required bool isDark,
  }) {
    final isSelected = _selectedBadge == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBadge = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBE1E1E).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Afficher le vrai badge ou une icône pour "aucun badge"
            if (id == null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.3),
                ),
                child: const Icon(Icons.close, color: Colors.grey, size: 24),
              )
            else
              MilitantBadge(badgeId: id, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFBE1E1E)
                      : (isDark ? Colors.white : Colors.black),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFBE1E1E),
              ),
          ],
        ),
      ),
    );
  }
}
