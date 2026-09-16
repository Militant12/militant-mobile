import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/error_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  File? _avatarFile;
  String? _currentAvatarUrl;

  // Controllers for profile fields
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  
  // Controllers for social links
  final _twitterController = TextEditingController();
  final _instagramController = TextEditingController();
  final _mastodonController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _blueskyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _websiteController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _mastodonController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _blueskyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();
      
      setState(() {
        _bioController.text = profile['bio'] ?? '';
        _websiteController.text = profile['website'] ?? '';
        _twitterController.text = profile['twitter'] ?? '';
        _instagramController.text = profile['instagram'] ?? '';
        _mastodonController.text = profile['mastodon'] ?? '';
        _facebookController.text = profile['facebook'] ?? '';
        _tiktokController.text = profile['tiktok'] ?? '';
        _blueskyController.text = profile['bluesky'] ?? '';
        _currentAvatarUrl = profile['avatar'] != null 
            ? api.getImageUrl(profile['avatar']) 
            : null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final lang = LanguageService.instance;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final api = await ApiService.getInstance();
      
      String? avatarPath;
      
      // Upload avatar if changed
      if (_avatarFile != null) {
        avatarPath = await api.uploadFile(_avatarFile!.path, type: 'avatar');
      }
      
      await api.updateProfile(
        bio: _bioController.text.trim(),
        website: _websiteController.text.trim(),
        avatar: avatarPath,
        twitter: _twitterController.text.trim(),
        instagram: _instagramController.text.trim(),
        mastodon: _mastodonController.text.trim(),
        facebook: _facebookController.text.trim(),
        tiktok: _tiktokController.text.trim(),
        bluesky: _blueskyController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('profile_updated'))),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final isDark = theme.brightness == Brightness.dark;
    final inputColor = theme.textTheme.bodyLarge?.color;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white30 : Colors.black26;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(lang.translate('edit_profile_title')),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBE1E1E),
                      ),
                    )
                  : Text(
                      lang.translate('save_button'),
                      style: const TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Avatar section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey[200],
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : (_currentAvatarUrl != null
                                  ? NetworkImage(_currentAvatarUrl!)
                                  : null) as ImageProvider?,
                          child: _avatarFile == null && _currentAvatarUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: labelColor,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFBE1E1E),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                              onPressed: _pickAvatar,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Bio section
                  _buildSectionHeader(lang.translate('profile_info_title')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 500,
                    style: TextStyle(color: inputColor),
                    decoration: InputDecoration(
                      labelText: lang.translate('bio_label'),
                      hintText: lang.translate('bio_hint'),
                      labelStyle: TextStyle(color: labelColor),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _websiteController,
                    style: TextStyle(color: inputColor),
                    decoration: InputDecoration(
                      labelText: lang.translate('website_label'),
                      hintText: 'https://example.com',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.link, color: labelColor),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                      ),
                    ),
                  ),
                  
                  // Social links section
                  const SizedBox(height: 32),
                  _buildSectionHeader(lang.translate('social_links_title')),
                  const SizedBox(height: 8),
                  _buildSocialField(
                    controller: _twitterController,
                    label: 'Twitter / X',
                    hint: '@username',
                    icon: Icons.alternate_email,
                    inputColor: inputColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                  ),
                  _buildSocialField(
                    controller: _instagramController,
                    label: 'Instagram',
                    hint: '@username',
                    icon: Icons.camera_alt,
                    inputColor: inputColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                  ),
                  _buildSocialField(
                    controller: _mastodonController,
                    label: 'Mastodon',
                    hint: '@username@instance.social',
                    icon: Icons.public,
                    inputColor: inputColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                  ),
                  _buildSocialField(
                    controller: _facebookController,
                    label: 'Facebook',
                    hint: 'username',
                    icon: Icons.facebook,
                    inputColor: inputColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                  ),
                  _buildSocialField(
                    controller: _tiktokController,
                    label: 'TikTok',
                    hint: '@username',
                    icon: Icons.music_note,
                    inputColor: inputColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                  ),
                  _buildSocialField(
                    controller: _blueskyController,
                    label: 'Bluesky',
                    hint: '@username.bsky.social',
                    icon: Icons.cloud,
                    inputColor: inputColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFBE1E1E),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color? inputColor,
    required Color labelColor,
    required Color borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: inputColor),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: labelColor),
          prefixIcon: Icon(icon, color: labelColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFBE1E1E)),
          ),
        ),
      ),
    );
  }
}
