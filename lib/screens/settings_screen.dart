import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          _buildOption(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Gérer les notifications',
          ),
          _buildOption(
            context,
            icon: Icons.privacy_tip,
            title: 'Confidentialité',
            subtitle: 'Paramètres de confidentialité',
          ),
          _buildOption(
            context,
            icon: Icons.language,
            title: 'Langue',
            subtitle: 'Français',
          ),
          _buildOption(
            context,
            icon: Icons.dark_mode,
            title: 'Thème',
            subtitle: 'Sombre',
          ),
          _buildOption(
            context,
            icon: Icons.info,
            title: 'À propos',
            subtitle: 'Version 1.0.0',
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité à venir')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFBE1E1E)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF888888)),
          ],
        ),
      ),
    );
  }
}
