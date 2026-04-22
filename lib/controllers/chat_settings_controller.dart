import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSettingsController extends ChangeNotifier {
  static const _fontKey = 'chat_font_size';
  static const _wallpaperKey = 'chat_wallpaper';

  double _fontSize = 15;
  String _wallpaperId = 'default';

  double get fontSize => _fontSize;
  String get wallpaperId => _wallpaperId;

  /// Map of wallpaper id → background color
  static const Map<String, int> wallpaperColors = {
    'default': 0xFFF0F2F5,
    'blue': 0xFFDCEEFF,
    'green': 0xFFDCF8C6,
    'purple': 0xFFF3E5F5,
    'pink': 0xFFFCE4EC,
    'dark': 0xFF1A1A2E,
  };

  Color get wallpaperColor =>
      Color(wallpaperColors[_wallpaperId] ?? wallpaperColors['default']!);

  ChatSettingsController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontKey) ?? 15;
    _wallpaperId = prefs.getString(_wallpaperKey) ?? 'default';
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontKey, size);
  }

  Future<void> setWallpaper(String id) async {
    _wallpaperId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wallpaperKey, id);
  }
}
