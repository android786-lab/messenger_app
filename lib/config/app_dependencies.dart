import '../features/calls/call_service.dart';
import '../repositories/notification_repository.dart';
import '../repositories/supabase_media_repository.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../services/supabase_service.dart';

/// Simple service locator — single instances for the app lifetime.
class AppDependencies {
  AppDependencies._();
  static final AppDependencies instance = AppDependencies._();

  late final SupabaseService supabaseService;
  late final SupabaseMediaRepository mediaRepository;
  late final NotificationService notificationService;
  late final NotificationRepository notificationRepository;
  late final PresenceService presenceService;
  late final CallService callService;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    supabaseService = SupabaseService();
    await supabaseService.initialize();

    mediaRepository = SupabaseMediaRepository(supabaseService);
    notificationService = NotificationService();
    await notificationService.initialize();
    notificationRepository =
        NotificationRepository(notificationService: notificationService);
    presenceService = PresenceService();
    callService = CallService();
    await callService.initialize();

    _initialized = true;
  }
}
