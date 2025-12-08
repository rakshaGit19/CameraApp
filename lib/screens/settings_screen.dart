import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(SettingsNotifier.provider);
    final notifier = ref.read(SettingsNotifier.provider.notifier);

    final List<String> fonts = [
      'Montserrat',
      'Playfair Display',
      'Poppins',
      'Inter',
      'Raleway',
    ];

    TextStyle getFontStyle(String family) {
      switch (family) {
        case 'Montserrat':
          return GoogleFonts.montserrat();
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay();
        case 'Poppins':
          return GoogleFonts.poppins();
        case 'Inter':
          return GoogleFonts.inter();
        case 'Raleway':
          return GoogleFonts.raleway();
        default:
          return GoogleFonts.montserrat();
      }
    }

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
              notifier.updateShowAddress(value);
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
              notifier.updateBoldAddress(value);
            },
          ),

          // FONT SELECTION (NEW)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Font Style',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.fontFamily,
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.amber,
                      ),
                      items: fonts.map((String font) {
                        return DropdownMenuItem<String>(
                          value: font,
                          child: Text(
                            font,
                            style: getFontStyle(
                              font,
                            ).copyWith(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          notifier.updateFontFamily(newValue);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
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
              notifier.updateFontSize(value!);
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
              notifier.updateFontSize(value!);
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
              notifier.updateFontSize(value!);
            },
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
              notifier.updateShowCoordinates(value);
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
              notifier.updateShowDateTime(value);
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
