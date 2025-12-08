import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart'; // NEW IMPORT

class SettingsScreen extends ConsumerWidget {
  // CHANGED: ConsumerWidget
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(SettingsNotifier.provider); // WATCH settings
    final notifier = ref.read(SettingsNotifier.provider.notifier); // NOTIFIER

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text(
          'GPS Stamp Settings',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stamp Settings Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stamp Overlay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Show Address',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              'City, State, Country',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            value: settings.showStampAddress,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateShowAddress(value); // RIVERPOD UPDATE
            },
          ),
          SwitchListTile(
            title: const Text(
              'Bold Address',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              'Make address text thicker/bolder',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            value: settings.boldAddress,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateBoldAddress(value); // RIVERPOD UPDATE
            },
          ),
          // Font Size Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Text Size',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Stamp text size',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          RadioListTile<String>(
            title: const Text('Small', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '14px',
              style: TextStyle(color: Colors.white60),
            ),
            value: 'small',
            groupValue: settings.fontSize,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateFontSize(value!); // RIVERPOD UPDATE
            },
          ),
          RadioListTile<String>(
            title: const Text(
              'Medium',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              '24px (Recommended)',
              style: TextStyle(color: Colors.white60),
            ),
            value: 'medium',
            groupValue: settings.fontSize,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateFontSize(value!); // RIVERPOD UPDATE
            },
          ),
          RadioListTile<String>(
            title: const Text('Large', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '48px',
              style: TextStyle(color: Colors.white60),
            ),
            value: 'large',
            groupValue: settings.fontSize,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateFontSize(value!); // RIVERPOD UPDATE
            },
          ),
          // Font Family Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font Style',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose stamp text font',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: DropdownButton<String>(
              value: settings.fontFamily,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: [
                DropdownMenuItem(
                  value: 'Montserrat',
                  child: Text(
                    'Montserrat',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Playfair Display',
                  child: Text(
                    'Playfair Display',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Poppins',
                  child: Text(
                    'Poppins',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Inter',
                  child: Text(
                    'Inter',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Raleway',
                  child: Text(
                    'Raleway',
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  notifier.updateFontFamily(value);
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Show GPS Coordinates',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              'Latitude, Longitude',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            value: settings.showStampCoordinates,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateShowCoordinates(value); // RIVERPOD UPDATE
            },
          ),
          SwitchListTile(
            title: const Text(
              'Show Date & Time',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              '2025-12-05 10:30 IST',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            value: settings.showStampDateTime,
            activeColor: Colors.amber,
            onChanged: (value) {
              notifier.updateShowDateTime(value); // RIVERPOD UPDATE
            },
          ),
          const SizedBox(height: 24),
          // Info Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settings saved automatically. Close this screen and capture a photo to see changes.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
