import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/error_helper.dart';

class CreatePageScreen extends StatefulWidget {
  const CreatePageScreen({super.key});

  @override
  State<CreatePageScreen> createState() => _CreatePageScreenState();
}

class _CreatePageScreenState extends State<CreatePageScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = '';
  bool _isLoading = false;

  List<Map<String, dynamic>> _getCategories() {
    final lang = LanguageService.instance;
    return [
      {'value': 'Syndicat', 'icon': Icons.groups, 'label': lang.translate('category_union')},
      {'value': 'Collectif', 'icon': Icons.people, 'label': lang.translate('category_collective')},
      {'value': 'Association', 'icon': Icons.handshake, 'label': lang.translate('category_association')},
      {'value': 'Média', 'icon': Icons.newspaper, 'label': lang.translate('category_media')},
      {'value': 'Squat / Lieu', 'icon': Icons.home, 'label': lang.translate('category_squat')},
      {'value': 'Infokiosque', 'icon': Icons.menu_book, 'label': lang.translate('category_infokiosk')},
      {'value': 'Artiste', 'icon': Icons.brush, 'label': lang.translate('category_artist')},
      {'value': 'Projet', 'icon': Icons.rocket_launch, 'label': lang.translate('category_project')},
      {'value': 'Autre', 'icon': Icons.more_horiz, 'label': lang.translate('category_other')},
    ];
  }

  Future<void> _createPage() async {
    final lang = LanguageService.instance;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.translate('name_required'))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      await api.createPage(
        name: name,
        description: _descController.text.trim(),
        category: _selectedCategory,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('page_created'))),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = _getCategories();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          lang.translate('create_page_title'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE1E1E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag,
                  color: Color(0xFFBE1E1E),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                lang.translate('create_page_for_cause'),
                style: TextStyle(
                  color: isDark ? const Color(0xFF888888) : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            Text(
              lang.translate('name_field'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: lang.translate('page_name_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.edit,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Text(
              lang.translate('category_field'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat['value'];
                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.grey[600]),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey[100],
                  selectedColor: const Color(0xFFBE1E1E),
                  checkmarkColor: Colors.white,
                  onSelected: (selected) {
                    setState(
                      () => _selectedCategory = selected
                          ? cat['value'] as String
                          : '',
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              lang.translate('description_field'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: lang.translate('describe_page_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createPage,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? lang.translate('creating') : lang.translate('create_page_button')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE1E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
