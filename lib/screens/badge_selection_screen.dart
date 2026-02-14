import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class BadgeSelectionScreen extends StatefulWidget {
  final String? currentBadge;

  const BadgeSelectionScreen({super.key, this.currentBadge});

  @override
  State<BadgeSelectionScreen> createState() => _BadgeSelectionScreenState();
}

class _BadgeSelectionScreenState extends State<BadgeSelectionScreen> {
  String? _selectedBadge;
  bool _isLoading = false;

  final List<Map<String, String>> _badges = [
    {'value': '', 'label': '', 'file': ''},  // Will use translation
    {'value': 'militant', 'label': 'MILITANT', 'file': 'militant'},
    {'value': 'antifa', 'label': 'Antifa', 'file': 'antifa'},
    {'value': 'anarchist', 'label': 'Anarchiste', 'file': 'anarchist'},
    {'value': 'cnt-ait', 'label': 'CNT-AIT', 'file': 'cnt-ait'},
    {'value': 'cnt-f', 'label': 'CNT-F', 'file': 'cnt-f'},
    {'value': 'cnt-so', 'label': 'CNT-SO', 'file': 'cnt-so'},
    {'value': 'fa', 'label': 'FA', 'file': 'fa'},
    {'value': 'ocl', 'label': 'OCL', 'file': 'ocl'},
    {'value': 'cga', 'label': 'CGA', 'file': 'cga'},
    {'value': 'ucl', 'label': 'UCL', 'file': 'ucl'},
    {'value': 'fll', 'label': 'FLL', 'file': 'fll'},
    {'value': 'slm', 'label': 'SLM', 'file': 'slm'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedBadge = widget.currentBadge ?? '';
  }

  Future<void> _saveBadge() async {
    setState(() => _isLoading = true);

    try {
      final api = await ApiService.getInstance();
      await api.updateMilitantBadge(_selectedBadge!.isEmpty ? null : _selectedBadge);

      if (mounted) {
        final lang = LanguageService.instance;
        Navigator.pop(context, _selectedBadge);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(lang.translate('my_militant_badge')),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
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
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveBadge,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('select_badge_text'),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _badges.length,
                    itemBuilder: (context, index) {
                      final badge = _badges[index];
                      final isSelected = _selectedBadge == badge['value'];
                      final lang = LanguageService.instance;
                      
                      // Use translation for "no badge" option
                      final displayLabel = badge['value']!.isEmpty 
                          ? lang.translate('no_badge')
                          : badge['label']!;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBadge = badge['value'];
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFBE1E1E)
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (badge['file']!.isNotEmpty)
                                Image.network(
                                  _getBadgeUrl(badge['file']!),
                                  width: 48,
                                  height: 48,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.flag,
                                      size: 48,
                                      color: Color(0xFFBE1E1E),
                                    );
                                  },
                                )
                              else
                                const Icon(
                                  Icons.block,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                displayLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFFBE1E1E)
                                      : theme.textTheme.bodyMedium?.color,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getBadgeUrl(String badgeFile) {
    // Déterminer l'extension du fichier
    final extensions = {
      'cnt-ait': 'png',
      'cnt-f': 'jpg',
      'cnt-so': 'png',
      'fa': 'png',
      'ocl': 'gif',
      'ucl': 'jpg',
      'fll': 'jpg',
      'slm': 'png',
    };

    final ext = extensions[badgeFile] ?? 'svg';
    return 'https://militant.revlibertaire.com/assets/badges/$badgeFile.$ext';
  }
}
