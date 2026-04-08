import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/app_lock_controller.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppLockController>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'App Lock',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<AppLockController>(
        builder: (context, appLockController, child) {
          if (appLockController.isLoading &&
              !appLockController.isDeviceSupported) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!appLockController.isDeviceSupported) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Device Not Supported',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your device doesn\'t support biometric authentication',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // App Lock Toggle
              _buildSectionHeader('Security'),
              _buildAppLockToggle(appLockController),
              const SizedBox(height: 24),

              // Biometric Information
              if (appLockController.hasBiometrics) ...[
                _buildSectionHeader('Available Biometrics'),
                _buildBiometricInfo(appLockController),
                const SizedBox(height: 24),
              ],

              // Test Authentication
              if (appLockController.isAppLockEnabled) ...[
                _buildSectionHeader('Test'),
                _buildTestAuthentication(appLockController),
                const SizedBox(height: 24),
              ],

              // Security Information
              _buildSectionHeader('Information'),
              _buildSecurityInfo(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAppLockToggle(AppLockController appLockController) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          appLockController.isAppLockEnabled ? Icons.lock : Icons.lock_open,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          'Enable App Lock',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          appLockController.isAppLockEnabled
              ? 'App lock is enabled. You\'ll need to authenticate to access the app.'
              : 'Enable biometric authentication to secure your messages.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        trailing: Switch(
          value: appLockController.isAppLockEnabled,
          onChanged: appLockController.isLoading
              ? null
              : (value) async {
                  if (value) {
                    // Show authentication dialog before enabling
                    bool authenticated = await _showEnableDialog(
                      appLockController,
                    );
                    if (authenticated) {
                      await appLockController.toggleAppLock();
                    }
                  } else {
                    // Show confirmation dialog before disabling
                    bool confirmed = await _showDisableDialog();
                    if (confirmed) {
                      await appLockController.toggleAppLock();
                    }
                  }
                },
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildBiometricInfo(AppLockController appLockController) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (String biometric in appLockController.availableBiometrics)
            ListTile(
              leading: Icon(
                _getBiometricIcon(biometric),
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                biometric,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Available on this device',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTestAuthentication(AppLockController appLockController) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.fingerprint,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'Test Authentication',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Test your biometric authentication',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _testAuthentication(appLockController),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              'How it works',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'App lock uses your device\'s built-in biometric authentication to secure your messages.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.timer_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              'Auto-lock',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'The app will automatically lock after 5 minutes of inactivity.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.security_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              'Privacy',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Your biometric data never leaves your device and is managed by the system.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBiometricIcon(String biometricType) {
    switch (biometricType.toLowerCase()) {
      case 'face id':
        return Icons.face;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'iris scanner':
        return Icons.visibility;
      default:
        return Icons.lock;
    }
  }

  Future<bool> _showEnableDialog(AppLockController appLockController) async {
    bool authenticated = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable App Lock'),
        content: Text(
          'Please authenticate with ${appLockController.primaryBiometricType} to enable app lock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              authenticated = await appLockController.authenticate(
                reason: 'Enable app lock',
              );
            },
            child: const Text('Authenticate'),
          ),
        ],
      ),
    );

    return authenticated;
  }

  Future<bool> _showDisableDialog() async {
    bool confirmed = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable App Lock'),
        content: const Text(
          'Are you sure you want to disable app lock? This will make your messages less secure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              confirmed = true;
              Navigator.pop(context);
            },
            child: const Text('Disable', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return confirmed;
  }

  Future<void> _testAuthentication(AppLockController appLockController) async {
    bool success = await appLockController.authenticate(
      reason: 'Test authentication',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Authentication successful!' : 'Authentication failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
