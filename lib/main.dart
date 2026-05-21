import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_dependencies.dart';
import 'config/env_config.dart';
import 'controllers/app_lock_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/block_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/chat_settings_controller.dart';
import 'controllers/contacts_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/calls/call_controller.dart';
import 'firebase_options.dart';
import 'screens/auth/app_lock_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'services/chat_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppDependencies.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ChatController()),
        ChangeNotifierProvider(create: (_) => ContactsController()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => BlockController()),
        ChangeNotifierProvider(create: (_) => AppLockController()),
        ChangeNotifierProvider(create: (_) => ChatSettingsController()),
        ChangeNotifierProvider(create: (_) => CallController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Facebook Messenger',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppLockController>(context, listen: false).initialize();
      _wireNotificationNavigation();
    });

    final authController =
        Provider.of<AuthController>(context, listen: false);
    _authSub = authController.authStateChanges.listen((user) {
      authController.initializeUser(user);
    });
  }

  void _wireNotificationNavigation() {
    AppDependencies.instance.notificationRepository.setChatNavigationHandler(
      (chatId) async {
        if (chatId == null || chatId.isEmpty) return;
        final nav = rootNavigatorKey.currentState;
        if (nav == null) return;
        final chatDoc = await ChatService().getChatStream(chatId).first;
        if (chatDoc == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              isGroup: chatDoc.isGroup,
              chatTitle: chatDoc.isGroup
                  ? (chatDoc.groupName ?? 'Group')
                  : 'Chat',
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    AppDependencies.instance.presenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthController, AppLockController>(
      builder: (context, authController, appLockController, child) {
        if (!authController.initialized) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        if (!authController.isAuthenticated) {
          return const LoginScreen();
        }

        if (appLockController.isAppLockEnabled) {
          return FutureBuilder<bool>(
            future: appLockController.needsReauthentication(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.data == true) {
                return const AppLockScreen();
              }

              return const ChatListScreen();
            },
          );
        }

        return const ChatListScreen();
      },
    );
  }
}
