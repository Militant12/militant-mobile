import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();
  final _githubController = TextEditingController();
  final _twitterController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _mastodonController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();

      setState(() {
        _bioController.text = profile['bio'] ?? '';
        _websiteController.text = profile['website'] ?? '';
        _locationController.text = profile['location'] ?? '';
        _githubController.text = profile['github'] ?? '';
        _twitterController.text = profile['twitter'] ?? '';
        _instagramController.text = profile['instagram'] ?? '';
        _facebookController.text = profile['facebook'] ?? '';
        _tiktokController.text = profile['tiktok'] ?? '';
        _mastodonController.text = profile['mastodon'] ?? '';
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final api = await ApiService.getInstance();
      await api.updateProfile(
        bio: _bioController.text.trim(),
        website: _websiteController.text.trim(),
        location: _locationController.text.trim(),
        github: _githubController.text.trim(),
        twitter: _twitterController.text.trim(),
        instagram: _instagramController.text.trim(),
        facebook: _facebookController.text.trim(),
        tiktok: _tiktokController.text.trim(),
        mastodon: _mastodonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: const Color(0xFFBE1E1E),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    _githubController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _mastodonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Modifier le profil',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFFBE1E1E),
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Enregistrer',
                style: TextStyle(
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biographie',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 500,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Parlez de vous...',
                        hintStyle: const TextStyle(color: Color(0xFF888888)),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: const TextStyle(color: Color(0xFF888888)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Site web',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://example.com',
                        hintStyle: const TextStyle(color: Color(0xFF888888)),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.link,
                          color: Color(0xFF888888),
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'L\'URL doit commencer par http:// ou https://';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Localisation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ville, Pays',
                        hintStyle: const TextStyle(color: Color(0xFF888888)),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Réseaux Sociaux',
                      style: TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSocialField(
                      _mastodonController,
                      'Mastodon',
                      Icons.alternate_email,
                    ),
                    _buildSocialField(_githubController, 'GitHub', Icons.code),
                    _buildSocialField(
                      _twitterController,
                      'Twitter',
                      Icons.chat_bubble_outline,
                    ),
                    _buildSocialField(
                      _instagramController,
                      'Instagram',
                      Icons.camera_alt_outlined,
                    ),
                    _buildSocialField(
                      _facebookController,
                      'Facebook',
                      Icons.facebook,
                    ),
                    _buildSocialField(
                      _tiktokController,
                      'TikTok',
                      Icons.music_note,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSocialField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Identifiant ou lien...',
              hintStyle: const TextStyle(color: Color(0xFF888888)),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }
}
