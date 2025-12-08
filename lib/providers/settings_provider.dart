import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final bool showStampAddress;
  final bool showStampCoordinates;
  final bool showStampDateTime;
  final bool boldAddress;
  final String fontSize;
  final String fontFamily;

  const Settings({
    this.showStampAddress = true,
    this.showStampCoordinates = true,
    this.showStampDateTime = true,
    this.boldAddress = false,
    this.fontSize = 'medium',
    this.fontFamily = 'Montserrat',
  });

  Settings copyWith({
    bool? showStampAddress,
    bool? showStampCoordinates,
    bool? showStampDateTime,
    bool? boldAddress,
    String? fontSize,
    String? fontFamily,
  }) {
    return Settings(
      showStampAddress: showStampAddress ?? this.showStampAddress,
      showStampCoordinates: showStampCoordinates ?? this.showStampCoordinates,
      showStampDateTime: showStampDateTime ?? this.showStampDateTime,
      boldAddress: boldAddress ?? this.boldAddress,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings()) {
    _loadSettings();
  }

  static final provider = StateNotifierProvider<SettingsNotifier, Settings>(
    (ref) => SettingsNotifier(),
  );

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = Settings(
      showStampAddress: prefs.getBool('showStampAddress') ?? true,
      showStampCoordinates: prefs.getBool('showStampCoordinates') ?? true,
      showStampDateTime: prefs.getBool('showStampDateTime') ?? true,
      boldAddress: prefs.getBool('boldAddress') ?? false,
      fontSize: prefs.getString('fontSize') ?? 'medium',
      fontFamily: prefs.getString('fontFamily') ?? 'Montserrat',
    );
  }

  Future<void> updateShowAddress(bool value) async {
    state = state.copyWith(showStampAddress: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showStampAddress', value);
  }

  Future<void> updateShowCoordinates(bool value) async {
    state = state.copyWith(showStampCoordinates: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showStampCoordinates', value);
  }

  Future<void> updateShowDateTime(bool value) async {
    state = state.copyWith(showStampDateTime: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showStampDateTime', value);
  }

  Future<void> updateBoldAddress(bool value) async {
    state = state.copyWith(boldAddress: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('boldAddress', value);
  }

  Future<void> updateFontSize(String value) async {
    state = state.copyWith(fontSize: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', value);
  }

  Future<void> updateFontFamily(String value) async {
    state = state.copyWith(fontFamily: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', value);
  }
}
