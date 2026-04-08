import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/app_lock_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/block_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/contacts_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/app_lock_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chat/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
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
  @override
  void initState() {
    super.initState();
    // Initialize app lock controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppLockController>(context, listen: false).initialize();
    });

    // Listen to auth state once and initialize user
    final authController = Provider.of<AuthController>(context, listen: false);
    authController.authStateChanges.listen((user) {
      authController.initializeUser(user);
    });
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

        // User is authenticated, check app lock
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
                // Need authentication
                return const AppLockScreen();
              }

              // Authentication not needed, show main app
              return const ChatListScreen();
            },
          );
        }

        // App lock not enabled, show main app
        return const ChatListScreen();
      },
    );
  }
}
