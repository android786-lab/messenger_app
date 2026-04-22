import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _lastSeenPrivacy = 'everyone';
  String _profilePhotoPrivacy = 'everyone';
  String _aboutPrivacy = 'everyone';
  String _onlineStatusPrivacy = 'everyone';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _lastSeenPrivacy = data['lastSeenPrivacy'] ?? 'everyone';
        _profilePhotoPrivacy = data['profilePhotoPrivacy'] ?? 'everyone';
        _aboutPrivacy = data['aboutPrivacy'] ?? 'everyone';
        _onlineStatusPrivacy = data['onlineStatusPrivacy'] ?? 'everyone';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save(String field, String value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .update({field: value});
  }

  void _showPicker(
      String title, String current, void Function(String) onChanged) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final option in ['everyone', 'contacts', 'nobody'])
              ListTile(
                title: Text(_label(option)),
                trailing: current == option
                    ? const Icon(Icons.check,
                        color: AppTheme.lightPrimaryColor)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onChanged(option);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _label(String v) {
    switch (v) {
      case 'everyone': return 'Everyone';
      case 'contacts': return 'My Contacts';
      case 'nobody': return 'Nobody';
      default: return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppTheme.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Privacy',
            style: TextStyle(
                color: AppTheme.lightTextPrimary,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Who can see my personal info',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.lightTextSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                      _PrivacyTile(
                        title: 'Last seen & Online',
                        subtitle: _label(_lastSeenPrivacy),
                        onTap: () => _showPicker(
                          'Last seen & Online',
                          _lastSeenPrivacy,
                          (v) {
                            setState(() => _lastSeenPrivacy = v);
                            _save('lastSeenPrivacy', v);
                          },
                        ),
                      ),
                      _PrivacyTile(
                        title: 'Profile photo',
                        subtitle: _label(_profilePhotoPrivacy),
                        onTap: () => _showPicker(
                          'Profile photo',
                          _profilePhotoPrivacy,
                          (v) {
                            setState(() => _profilePhotoPrivacy = v);
                            _save('profilePhotoPrivacy', v);
                          },
                        ),
                      ),
                      _PrivacyTile(
                        title: 'About',
                        subtitle: _label(_aboutPrivacy),
                        onTap: () => _showPicker(
                          'About',
                          _aboutPrivacy,
                          (v) {
                            setState(() => _aboutPrivacy = v);
                            _save('aboutPrivacy', v);
                          },
                        ),
                      ),
                      _PrivacyTile(
                        title: 'Online status',
                        subtitle: _label(_onlineStatusPrivacy),
                        onTap: () => _showPicker(
                          'Online status',
                          _onlineStatusPrivacy,
                          (v) {
                            setState(() => _onlineStatusPrivacy = v);
                            _save('onlineStatusPrivacy', v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Messaging',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.lightTextSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_outline,
                            color: AppTheme.lightTextPrimary),
                        title: const Text('End-to-end encryption'),
                        subtitle: const Text(
                          'Messages and calls are end-to-end encrypted.',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrivacyTile(
      {required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppTheme.lightPrimaryColor, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right,
          color: AppTheme.lightTextSecondary),
      onTap: onTap,
    );
  }
}
