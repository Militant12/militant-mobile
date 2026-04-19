import 'package:flutter/material.dart';
import '../services/language_service.dart';

class TechnicianBadge extends StatelessWidget {
  final double size;

  const TechnicianBadge({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: LanguageService.instance.translate('technician_badge_tooltip'),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFBE1E1E), Color(0xFFFF4C4C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBE1E1E).withOpacity(0.4),
              blurRadius: size * 0.2,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '🔧',
            style: TextStyle(fontSize: size * 0.5),
          ),
        ),
      ),
    );
  }
}
