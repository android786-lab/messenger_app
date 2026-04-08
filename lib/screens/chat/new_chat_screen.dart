import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/local_contact_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../group/create_group_screen.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  List<Map<String, dynamic>> _onApp = [];
  List<LocalContact> _notOnApp = [];
  List<Map<String, dynamic>> _filteredOnApp = [];
  List<LocalContact> _filteredNotOnApp = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredOnApp = List.from(_onApp);
        _filteredNotOnApp = List.from(_notOnApp);
      } else {
        _filteredOnApp = _onApp.where((entry) {
          final contact = entry['contact'] as LocalContact;
          return contact.name.toLowerCase().contains(query) ||
              contact.phone.toLowerCase().contains(query);
        }).toList();
        _filteredNotOnApp = _notOnApp.where((contact) {
          return contact.name.toLowerCase().contains(query) ||
              contact.phone.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadContacts() async {
    final ctrl = Provider.of<ContactsController>(context, listen: false);
    if (ctrl.contacts.isEmpty) await ctrl.loadContacts();

    final result = await ctrl.getContactsWithAppStatus();
    if (mounted) {
      setState(() {
        _onApp = List<Map<String, dynamic>>.from(result['onApp']);
        _notOnApp = List<LocalContact>.from(result['notOnApp']);
        _filteredOnApp = List.from(_onApp);
        _filteredNotOnApp = List.from(_notOnApp);
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(UserModel user, String contactName) async {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final chatId = await chatController.getOrCreateChat(user.uid);
    if (chatId != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            isGroup: false,
            chatTitle: contactName,
          ),
        ),
      );
    }
  }

  Future<void> _invite(LocalContact contact) async {
    final message = Uri.encodeComponent(
      'Hey ${contact.name}! I\'m using this messenger app to chat. Download it and sign up so we can connect: https://play.google.com/store/apps/details?id=com.example.facebook_messanger',
    );
    final uri = Uri.parse('sms:${contact.phone}?body=$message');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback without number
      try {
        await launchUrl(
          Uri.parse('sms:?body=$message'),
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open SMS app.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Chat',
          style: TextStyle(
            color: AppTheme.lightTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.lightPrimaryColor,
                ),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Search Bar
        _buildSearchBar(),

        // Content
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_onApp.isEmpty && _notOnApp.isEmpty) {
      return _buildEmptyState();
    }

    // Use filtered lists when searching
    final onAppList = _isSearching ? _filteredOnApp : _onApp;
    final notOnAppList = _isSearching ? _filteredNotOnApp : _notOnApp;

    // Show no results when searching and nothing found
    if (_isSearching && onAppList.isEmpty && notOnAppList.isEmpty) {
      return _buildNoSearchResults();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // New Group Option (only show when not searching)
        if (!_isSearching) ...[
          _buildNewGroupOption(),
          const Divider(height: 1, indent: 72),
        ],

        // On this app section
        if (onAppList.isNotEmpty) ...[
          _sectionHeader(
            _isSearching ? 'Contacts on this app' : 'Contacts on this app',
          ),
          ...onAppList.map((entry) => _buildContactTile(entry)),
        ],

        // Invite section
        if (notOnAppList.isNotEmpty) ...[
          _sectionHeader(
            _isSearching ? 'Invite to this app' : 'Invite to this app',
          ),
          ...notOnAppList.map((contact) => _buildInviteTile(contact)),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No contacts yet',
            style: TextStyle(
              fontSize: 20,
              color: AppTheme.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add contacts to start chatting',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to contacts tab
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Add Contacts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNewGroupOption() {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.group_add,
                color: AppTheme.lightPrimaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'New Group',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> entry) {
    final contact = entry['contact'] as LocalContact;
    final initialUser = entry['user'] as UserModel;

    // Use StreamBuilder to get real-time online status updates
    return StreamBuilder<UserModel?>(
      stream: AuthService().streamUserById(initialUser.uid),
      initialData: initialUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? initialUser;
        final isOnline = user.isOnline;

        return InkWell(
          onTap: () => _startChat(user, contact.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.lightPrimaryColor,
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(
                              contact.name.isNotEmpty
                                  ? contact.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Contact info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline ? 'Online' : contact.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: isOnline
                              ? const Color(0xFF00C853)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteTile(LocalContact contact) {
    return InkWell(
      onTap: () => _invite(contact),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFF0F2F5),
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.phone,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Invite button
            TextButton(
              onPressed: () => _invite(contact),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.lightPrimaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Invite',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
