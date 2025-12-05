import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _showStampAddress = true;
  bool _showStampCoordinates = true;
  bool _showStampDateTime = true;
  bool _boldAddress = false;
  String _fontSize = 'medium';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showStampAddress = prefs.getBool('showStampAddress') ?? true;
        _showStampCoordinates = prefs.getBool('showStampCoordinates') ?? true;
        _showStampDateTime = prefs.getBool('showStampDateTime') ?? true;
        _boldAddress = prefs.getBool('boldAddress') ?? false;
        _fontSize = prefs.getString('fontSize') ?? 'medium'; // 👈 ADD THIS

        _isLoading = false;
      });
      print('Settings Screen Loaded:');
      print('   Address: $_showStampAddress');
      print('   Coordinates: $_showStampCoordinates');
      print('   DateTime: $_showStampDateTime');
      print('   Bold Address: $_boldAddress');
      print('   Font Size: $_fontSize'); // 👈 ADD THIS
    }
  }

  // Save setting to SharedPreferences
  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    print('💾 Saved $key = $value');
  }

  // Save string setting to SharedPreferences (for font size)
  Future<void> _updateStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    print('💾 Saved $key = $value');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
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
            value: _showStampAddress,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _showStampAddress = value);
              _updateSetting('showStampAddress', value);
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
            value: _boldAddress,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _boldAddress = value);
              _updateSetting('boldAddress', value);
            },
          ),

          // 👈 FONT SIZE SECTION 👇
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
            groupValue: _fontSize,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _fontSize = value!);
              _updateStringSetting('fontSize', value!);
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
            groupValue: _fontSize,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _fontSize = value!);
              _updateStringSetting('fontSize', value!);
            },
          ),

          RadioListTile<String>(
            title: const Text('Large', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '48px',
              style: TextStyle(color: Colors.white60),
            ),
            value: 'large',
            groupValue: _fontSize,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _fontSize = value!);
              _updateStringSetting('fontSize', value!);
            },
          ),

          // 👈 FONT SIZE SECTION ENDS 👆
          SwitchListTile(
            title: const Text(
              'Show GPS Coordinates',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              'Latitude, Longitude',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            value: _showStampCoordinates,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _showStampCoordinates = value);
              _updateSetting('showStampCoordinates', value);
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
            value: _showStampDateTime,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() => _showStampDateTime = value);
              _updateSetting('showStampDateTime', value);
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
