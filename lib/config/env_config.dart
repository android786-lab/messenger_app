import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration loaded from `.env`.
class EnvConfig {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (_) {
      // .env missing in dev — services check isConfigured flags
      _loaded = true;
    }
  }

  static String get supabaseUrl => dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';

  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static int get zegoAppId {
    final raw = dotenv.maybeGet('ZEGO_APP_ID')?.trim() ?? '0';
    return int.tryParse(raw) ?? 0;
  }

  static String get zegoAppSign =>
      dotenv.maybeGet('ZEGO_APP_SIGN')?.trim() ?? '';

  static bool get isZegoConfigured =>
      zegoAppId > 0 && zegoAppSign.isNotEmpty;
}
