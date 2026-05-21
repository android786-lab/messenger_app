import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';

class SupabaseService {
  bool _initialized = false;

  bool get isConfigured => EnvConfig.isSupabaseConfigured;

  bool get isInitialized => _initialized;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!EnvConfig.isSupabaseConfigured) return;

    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }
}
