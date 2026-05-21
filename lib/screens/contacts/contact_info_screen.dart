import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/local_contact_model.dart';
import '../../models/user_model.dart';
import '../../features/calls/call_helpers.dart';
import '../../services/auth_service.dart';
import 'edit_contact_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  final String chatId;
  final String displayName;
  final bool isGroup;

  const ContactInfoScreen({
    super.key,
    required this.chatId,
    required this.displayName,
    required this.isGroup,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  UserModel? _user;
  LocalContact? _contact;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    if (widget.isGroup) {
      setState(() => _isLoading = false);
      return;
    }

    final contactsController = Provider.of<ContactsController>(
      context,
      listen: false,
    );

    // Derive other user ID from chatId (format: uid1_uid2)
    final parts = widget.chatId.split('_');
    final authService = AuthService();
    UserModel? user;
    for (final part in parts) {
      final u = await authService.getUserById(part);
      if (u != null) {
        user = u;
        // We'll pick the one that isn't the current user later if needed
        // For now just try both and keep the last valid one that matches display
      }
    }

    // Load contacts to find saved contact
    await contactsController.loadContacts();
    LocalContact? contact;

    if (user != null && user.phone != null && user.phone!.isNotEmpty) {
      try {
        contact = contactsController.contacts.firstWhere(
          (c) =>
              c.phone.replaceAll(RegExp(r'\D'), '') ==
              user!.phone!.replaceAll(RegExp(r'\D'), ''),
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _user = user;
        _contact = contact;
        _isLoading = false;
      });
    }
  }

  void _shareContact() {
    final name = _contact?.name ?? _user?.name ?? widget.displayName;
    final phone = _contact?.phone ?? _user?.phone ?? '';
    final email = _contact?.email ?? _user?.email ?? '';
    final company = _contact?.company ?? '';
    final jobTitle = _contact?.jobTitle ?? '';
    final address = _contact?.address ?? '';

    final buffer = StringBuffer();
    buffer.writeln('Contact: $name');
    if (phone.isNotEmpty) buffer.writeln('Phone: $phone');
    if (email.isNotEmpty) buffer.writeln('Email: $email');
    if (company.isNotEmpty) buffer.writeln('Company: $company');
    if (jobTitle.isNotEmpty) buffer.writeln('Job Title: $jobTitle');
    if (address.isNotEmpty) buffer.writeln('Address: $address');

    Share.share(buffer.toString().trim(), subject: name);
  }

  Future<void> _editContact(BuildContext ctx) async {
    if (_contact == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('This contact is not saved. Add them as a contact first.'),
        ),
      );
      return;
    }

    final updated = await Navigator.push<LocalContact>(
      ctx,
      MaterialPageRoute(
        builder: (_) => EditContactScreen(contact: _contact!),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _contact = updated);
    }
  }

  void _showVerifySecurityCode(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Security Code'),
        content: const Text(
          'Messages and calls are end-to-end encrypted. Only you and the recipient can read or listen to them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _contact?.name ?? _user?.name ?? widget.displayName;
    final phone = _contact?.phone ?? _user?.phone ?? '';
    final photoUrl = _contact?.photoUrl ?? _user?.photoUrl;
    final email = _contact?.email ?? _user?.email ?? '';
    final address = _contact?.address;
    final company = _contact?.company;
    final jobTitle = _contact?.jobTitle;
    final notes = _contact?.notes;
    final nickname = _contact?.nickname;
    final birthday = _contact?.birthday;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.lightPrimaryColor,
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.lightTextPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: const Text(
                    'Contact Info',
                    style: TextStyle(
                      color: AppTheme.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppTheme.lightTextPrimary,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'share':
                            _shareContact();
                            break;
                          case 'edit':
                            _editContact(context);
                            break;
                          case 'verify':
                            _showVerifySecurityCode(context);
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'share', child: Text('Share')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'verify',
                          child: Text('Verify security code'),
                        ),
                      ],
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Profile header
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: AppTheme.lightPrimaryColor,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            // Name
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.lightTextPrimary,
                              ),
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                            if (nickname != null && nickname.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                nickname,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ActionButton(
                                  icon: Icons.call_outlined,
                                  label: 'Audio',
                                  onTap: () {
                                    if (_user == null) return;
                                    startCallWithUser(
                                      context: context,
                                      targetUserId: _user!.uid,
                                      targetUserName: name,
                                      isVideo: false,
                                    );
                                  },
                                ),
                                const SizedBox(width: 24),
                                _ActionButton(
                                  icon: Icons.videocam_outlined,
                                  label: 'Video',
                                  onTap: () {
                                    if (_user == null) return;
                                    startCallWithUser(
                                      context: context,
                                      targetUserId: _user!.uid,
                                      targetUserName: name,
                                      isVideo: true,
                                    );
                                  },
                                ),
                                const SizedBox(width: 24),
                                _ActionButton(
                                  icon: Icons.search,
                                  label: 'Search',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Contact details section
                      if (email.isNotEmpty ||
                          address != null ||
                          company != null ||
                          jobTitle != null ||
                          birthday != null)
                        _InfoSection(
                          children: [
                            if (email.isNotEmpty)
                              _InfoTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: email,
                              ),
                            if (company != null && company.isNotEmpty)
                              _InfoTile(
                                icon: Icons.business_outlined,
                                label: 'Company',
                                value: company,
                              ),
                            if (jobTitle != null && jobTitle.isNotEmpty)
                              _InfoTile(
                                icon: Icons.work_outline,
                                label: 'Job Title',
                                value: jobTitle,
                              ),
                            if (address != null && address.isNotEmpty)
                              _InfoTile(
                                icon: Icons.location_on_outlined,
                                label: 'Address',
                                value: address,
                              ),
                            if (birthday != null)
                              _InfoTile(
                                icon: Icons.cake_outlined,
                                label: 'Birthday',
                                value:
                                    '${birthday.day}/${birthday.month}/${birthday.year}',
                              ),
                          ],
                        ),

                      if (email.isNotEmpty ||
                          address != null ||
                          company != null ||
                          jobTitle != null ||
                          birthday != null)
                        const SizedBox(height: 8),

                      // Media, links, and docs
                      _InfoSection(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.photo_library_outlined,
                              color: AppTheme.lightTextPrimary,
                            ),
                            title: const Text('Media, links, and docs'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.lightTextSecondary,
                            ),
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Settings section
                      _InfoSection(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.storage_outlined,
                              color: AppTheme.lightTextPrimary,
                            ),
                            title: const Text('Manage Storage'),
                            subtitle: const Text(
                              '0 B',
                              style: TextStyle(
                                color: AppTheme.lightTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.lightTextSecondary,
                            ),
                            onTap: () {},
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.lightTextPrimary,
                            ),
                            title: const Text('Notifications'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.lightTextSecondary,
                            ),
                            onTap: () {},
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.perm_media_outlined,
                              color: AppTheme.lightTextPrimary,
                            ),
                            title: const Text('Media visibility'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.lightTextSecondary,
                            ),
                            onTap: () {},
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.lock_outline,
                              color: AppTheme.lightTextPrimary,
                            ),
                            title: const Text('Encryption'),
                            subtitle: const Text(
                              'Messages and calls are end-to-end encrypted.',
                              style: TextStyle(
                                color: AppTheme.lightTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.lightTextSecondary,
                            ),
                            onTap: () {},
                          ),
                        ],
                      ),

                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoSection(
                          children: [
                            _InfoTile(
                              icon: Icons.notes_outlined,
                              label: 'Notes',
                              value: notes,
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.lightPrimaryColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final List<Widget> children;

  const _InfoSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.lightTextPrimary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.lightTextSecondary,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: AppTheme.lightTextPrimary,
        ),
      ),
    );
  }
}
