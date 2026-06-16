import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      title: 'API Configuration',
                      subtitle: 'Configure Sarvam AI API settings',
                      icon: Icons.api,
                    ),
                    const Divider(),
                    _buildSettingsTile(
                      title: 'Audio Quality',
                      subtitle: 'Set default audio quality preferences',
                      icon: Icons.audio_file,
                    ),
                    const Divider(),
                    _buildSettingsTile(
                      title: 'Export Settings',
                      subtitle: 'Configure output format and location',
                      icon: Icons.download,
                    ),
                    const Divider(),
                    _buildSettingsTile(
                      title: 'Notifications',
                      subtitle: 'Manage job completion alerts',
                      icon: Icons.notifications,
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

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF4F46E5)),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}