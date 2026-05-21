import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../features/calls/call_controller.dart';
import '../../controllers/block_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_model.dart';
import '../../models/local_contact_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/chat_tile.dart';
import '../auth/login_screen.dart';
import '../contacts/add_contact_screen.dart';
import '../group/create_group_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  late TextEditingController _searchController;
  String _selectedFilter = 'All';
  bool _isSearching = false;
  List<ChatModel> _searchResults = [];

  // Multi-selection support
  final Set<String> _selectedChatIds = <String>{};
  bool get _isSelectionMode => _selectedChatIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatController>(context, listen: false).listenToUserChats();
      // Initialize blocked users stream (requires auth — safe here since
      // ChatListScreen is only shown when authenticated)
      Provider.of<BlockController>(context, listen: false)
          .initializeBlockedUsers();
      final uid =
          Provider.of<AuthController>(context, listen: false).currentUser?.uid;
      if (uid != null) {
        Provider.of<CallController>(context, listen: false)
            .listenForIncomingCalls(context, uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
    } else {
      setState(() => _isSearching = true);
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);
    final contactsController =
        Provider.of<ContactsController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';
    final searchLower = query.toLowerCase();

    // Ensure contacts are loaded
    await contactsController.loadContacts();

    final results = <ChatModel>[];

    for (final chat in chatController.chats) {
      String displayName;

      if (chat.isGroup) {
        displayName = (chat.groupName ?? 'Group Chat').toLowerCase();
      } else {
        // Resolve the other participant's display name
        final otherUserId = chat.participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        // Try to find saved contact name first
        String resolvedName = otherUserId;
        try {
          final user = await AuthService().getUserById(otherUserId);
          if (user != null) {
            resolvedName = user.name;
            // Check if saved as a contact
            if (user.phone != null && user.phone!.isNotEmpty) {
              try {
                final contact = contactsController.contacts.firstWhere(
                  (c) =>
                      c.phone.replaceAll(RegExp(r'\D'), '') ==
                      user.phone!.replaceAll(RegExp(r'\D'), ''),
                );
                resolvedName = contact.name;
              } catch (_) {}
            }
          }
        } catch (_) {}

        displayName = resolvedName.toLowerCase();
      }

      // Also search in last message content
      final lastMsg = chat.lastMessage.toLowerCase();

      if (displayName.contains(searchLower) || lastMsg.contains(searchLower)) {
        results.add(chat);
      }
    }

    if (mounted) {
      setState(() => _searchResults = results);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults.clear();
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChatIds.clear();
    });
  }

  Future<void> _pinSelectedChats() async {
    if (_selectedChatIds.isNotEmpty) {
      final chatController = Provider.of<ChatController>(
        context,
        listen: false,
      );

      // Check if all selected chats are pinned
      final selectedChats = chatController.chats
          .where((chat) => _selectedChatIds.contains(chat.chatId))
          .toList();

      final allPinned = selectedChats.every((chat) => chat.isPinned);

      // If trying to pin (not unpin), check the limit
      if (!allPinned) {
        // Count already pinned chats
        final pinnedChats = chatController.chats
            .where((chat) => chat.isPinned)
            .toList();
        final alreadyPinnedCount = pinnedChats.length;

        // Count how many selected chats are not yet pinned
        final notPinnedSelected = selectedChats
            .where((chat) => !chat.isPinned)
            .length;

        // Check if adding these would exceed the limit of 2
        if (alreadyPinnedCount + notPinnedSelected > 2) {
          // Show limit reached message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You can only pin 2 chats. Unpin one first to pin another.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // Toggle: if all are pinned, unpin them; otherwise pin them
      final newPinStatus = !allPinned;

      for (final id in _selectedChatIds.toList()) {
        await chatController.updateChatPinStatus(id, newPinStatus);
      }
      _clearSelection();
    }
  }

  Future<void> _archiveSelectedChats() async {
    if (_selectedChatIds.isNotEmpty) {
      final chatController = Provider.of<ChatController>(
        context,
        listen: false,
      );
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      for (final id in _selectedChatIds.toList()) {
        await chatController.updateChatArchiveStatus(id, true);
      }
      _clearSelection();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Chat(s) archived'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _unarchiveSelectedChats() async {
    if (_selectedChatIds.isNotEmpty) {
      final chatController = Provider.of<ChatController>(
        context,
        listen: false,
      );
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      for (final id in _selectedChatIds.toList()) {
        await chatController.updateChatArchiveStatus(id, false);
      }
      _clearSelection();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Chat(s) unarchived'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isNotEmpty) {
      final chatController = Provider.of<ChatController>(
        context,
        listen: false,
      );
      final confirmed = await _showDeleteConfirmationDialog();
      if (confirmed) {
        for (final id in _selectedChatIds.toList()) {
          await chatController.deleteChat(id);
        }
        _clearSelection();
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete the selected chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.lightErrorColor),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);
    switch (state) {
      case AppLifecycleState.resumed:
        authController.updateOnlineStatus(true);
        // Re-subscribe to chats stream to ensure latest data
        chatController.listenToUserChats();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        authController.updateOnlineStatus(false);
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Widget _buildFilterChip(String filter) {
    final chatController = Provider.of<ChatController>(context);
    int unreadCount = 0;

    if (filter == 'Unread') {
      // Count contacts with unread messages (not total unread messages)
      final currentUserId =
          Provider.of<AuthController>(
            context,
            listen: false,
          ).currentUser?.uid ??
          '';
      unreadCount = chatController.chats
          .where((chat) => (chat.unreadCount[currentUserId] ?? 0) > 0)
          .length;
    } else if (filter == 'Groups') {
      // Count groups with unread messages
      final currentUserId =
          Provider.of<AuthController>(
            context,
            listen: false,
          ).currentUser?.uid ??
          '';
      unreadCount = chatController.chats
          .where(
            (chat) =>
                chat.isGroup && (chat.unreadCount[currentUserId] ?? 0) > 0,
          )
          .length;
    }

    return FilterChip(
      label: Text(
        (filter == 'Unread' || filter == 'Groups') && unreadCount > 0
            ? '$filter $unreadCount'
            : filter,
      ),
      selected: _selectedFilter == filter,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: _selectedFilter == filter
            ? AppTheme.lightPrimaryColor
            : AppTheme.lightTextSecondary,
        fontWeight: _selectedFilter == filter
            ? FontWeight.w600
            : FontWeight.normal,
      ),
      backgroundColor: const Color(0xFFF0F2F5),
      side: BorderSide(
        color: _selectedFilter == filter
            ? AppTheme.lightPrimaryColor
            : Colors.transparent,
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    await authController.signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _showChatOptionsMenu() {
    // Only show menu if exactly one chat is selected for view contact
    if (_selectedChatIds.length != 1) {
      // Show menu without view contact option for multiple selections
      _showMultiSelectMenu();
      return;
    }

    final chatController = Provider.of<ChatController>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';

    // Get the selected chat
    final selectedChatId = _selectedChatIds.first;
    ChatModel? selectedChat;
    try {
      selectedChat = chatController.chats.firstWhere(
        (chat) => chat.chatId == selectedChatId,
      );
    } catch (e) {
      selectedChat = null;
    }

    if (selectedChat == null) return;

    // Determine if chat has unread messages
    final unreadCount = selectedChat.unreadCount[currentUserId] ?? 0;
    final hasUnread = unreadCount > 0;

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: <PopupMenuEntry<String>>[
        // Only show View Contact for single selection and non-group chats
        if (!selectedChat.isGroup)
          PopupMenuItem<String>(
            value: 'view_contact',
            child: Row(
              children: [
                Icon(Icons.person, color: AppTheme.lightPrimaryColor),
                const SizedBox(width: 12),
                const Text('View contact'),
              ],
            ),
          ),
        // Dynamic Mark as Read/Unread
        PopupMenuItem<String>(
          value: hasUnread ? 'mark_as_read' : 'mark_as_unread',
          child: Row(
            children: [
              Icon(
                hasUnread ? Icons.mark_chat_read : Icons.mark_chat_unread,
                color: AppTheme.lightPrimaryColor,
              ),
              const SizedBox(width: 12),
              Text(hasUnread ? 'Mark as read' : 'Mark as unread'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'select_all',
          child: Row(
            children: [
              Icon(Icons.select_all, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Select all'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'lock_chat',
          child: Row(
            children: [
              Icon(Icons.lock, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Lock chat'),
            ],
          ),
        ),
        // Dynamic Add/Remove from Favourites
        PopupMenuItem<String>(
          value: selectedChat.isFavorite
              ? 'remove_from_favorites'
              : 'add_to_favorites',
          child: Row(
            children: [
              Icon(
                selectedChat.isFavorite ? Icons.star : Icons.star_border,
                color: selectedChat.isFavorite
                    ? Colors.amber
                    : AppTheme.lightPrimaryColor,
              ),
              const SizedBox(width: 12),
              Text(
                selectedChat.isFavorite
                    ? 'Remove from Favourites'
                    : 'Add to Favourites',
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear_chat',
          child: Row(
            children: [
              Icon(Icons.cleaning_services, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Clear chat'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'block',
          child: Row(
            children: [
              const Icon(Icons.block, color: AppTheme.lightErrorColor),
              const SizedBox(width: 12),
              const Text(
                'Block',
                style: TextStyle(color: AppTheme.lightErrorColor),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleMenuAction(value, selectedChat);
      }
    });
  }

  void _showMultiSelectMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'select_all',
          child: Row(
            children: [
              Icon(Icons.select_all, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Select all'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'lock_chat',
          child: Row(
            children: [
              Icon(Icons.lock, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Lock chat'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_favorites',
          child: Row(
            children: [
              Icon(Icons.star, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Add to Favourites'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear_chat',
          child: Row(
            children: [
              Icon(Icons.cleaning_services, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Clear chat'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'block',
          child: Row(
            children: [
              const Icon(Icons.block, color: AppTheme.lightErrorColor),
              const SizedBox(width: 12),
              const Text(
                'Block',
                style: TextStyle(color: AppTheme.lightErrorColor),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleMenuAction(value, null);
      }
    });
  }

  void _handleMenuAction(String action, ChatModel? selectedChat) {
    final chatController = Provider.of<ChatController>(context, listen: false);

    switch (action) {
      case 'view_contact':
        if (selectedChat != null && !selectedChat.isGroup) {
          _viewContact(selectedChat);
        }
        break;
      case 'mark_as_read':
        if (selectedChat != null) {
          _markChatAsRead(selectedChat);
        }
        break;
      case 'mark_as_unread':
        if (selectedChat != null) {
          _markChatAsUnread(selectedChat);
        }
        break;
      case 'select_all':
        _selectAllChats(chatController.chats);
        break;
      case 'lock_chat':
        // TODO: Implement lock chat
        break;
      case 'add_to_favorites':
        if (selectedChat != null) {
          _addToFavorites(selectedChat);
        }
        break;
      case 'remove_from_favorites':
        if (selectedChat != null) {
          _removeFromFavorites(selectedChat);
        }
        break;
      case 'clear_chat':
        if (selectedChat != null) {
          _clearChat(selectedChat);
        }
        break;
      case 'block':
        // TODO: Implement block
        break;
    }
  }

  Widget _buildArchivedFolder() {
    final chatController = Provider.of<ChatController>(context);
    final archivedCount = chatController.chats
        .where((chat) => chat.isArchived)
        .length;

    if (archivedCount == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = 'Archived';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.archive,
                color: AppTheme.lightPrimaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Archived',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '$archivedCount chat${archivedCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.lightTextSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToFavorites(ChatModel chat) async {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await chatController.updateChatFavoriteStatus(chat.chatId, true);
    _clearSelection();
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Added to favourites'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeFromFavorites(ChatModel chat) async {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await chatController.updateChatFavoriteStatus(chat.chatId, false);
    _clearSelection();
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Removed from favourites'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearChat(ChatModel chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Are you sure you want to clear all messages in this chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppTheme.lightErrorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final chatController = Provider.of<ChatController>(
        context,
        listen: false,
      );
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      await chatController.clearChatMessages(chat.chatId);
      _clearSelection();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Chat cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _viewContact(ChatModel chat) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final contactsController = Provider.of<ContactsController>(
      context,
      listen: false,
    );
    final currentUserId = authController.currentUser?.uid ?? '';

    // Get other user's ID
    String otherUserId = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return;

    // Get user details
    final user = await AuthService().getUserById(otherUserId);
    if (user == null || !context.mounted) return;

    // Load contacts to find if this user is saved as a contact
    await contactsController.loadContacts();
    if (!context.mounted) return;

    // Find contact by phone
    LocalContact? contact;
    if (user.phone != null && user.phone!.isNotEmpty) {
      try {
        contact = contactsController.contacts.firstWhere(
          (c) =>
              c.phone.replaceAll(RegExp(r'\D'), '') ==
              user.phone!.replaceAll(RegExp(r'\D'), ''),
        );
      } catch (e) {
        contact = null;
      }
    }

    // Show contact details dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.lightPrimaryColor,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              contact?.name ?? user.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user.phone ?? 'No phone number',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            if (contact != null) ...[
              const SizedBox(height: 8),
              const Chip(
                label: Text('Saved Contact'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markChatAsRead(ChatModel chat) async {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await chatController.markChatAsRead(chat.chatId, currentUserId);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _markChatAsUnread(ChatModel chat) async {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // To mark as unread, we set the unread count to 1
    await chatController.markChatAsUnread(chat.chatId, currentUserId);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Marked as unread'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _selectAllChats(List<ChatModel> chats) {
    setState(() {
      _selectedChatIds.clear();
      for (final c in chats) {
        _selectedChatIds.add(c.chatId);
      }
    });
  }

  void _showOptionsMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'add_contact',
          child: Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Add Contact'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'new_chat',
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: AppTheme.lightPrimaryColor,
              ),
              const SizedBox(width: 12),
              const Text('New Chat'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'create_group',
          child: Row(
            children: [
              Icon(Icons.group_add, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Create Group'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Profile'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: AppTheme.lightPrimaryColor),
              const SizedBox(width: 12),
              const Text('Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'sign_out',
          child: Row(
            children: [
              const Icon(Icons.logout, color: AppTheme.lightErrorColor),
              const SizedBox(width: 12),
              const Text(
                'Sign Out',
                style: TextStyle(color: AppTheme.lightErrorColor),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleOptionsMenuAction(value);
      }
    });
  }

  void _handleOptionsMenuAction(String value) {
    switch (value) {
      case 'add_contact':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddContactScreen()),
        );
        break;
      case 'new_chat':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewChatScreen()),
        );
        break;
      case 'create_group':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        );
        break;
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      case 'sign_out':
        _handleSignOut();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackgroundColor,
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search or start a new chat',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.lightTextSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.lightTextSecondary,
                        ),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ),

          // Search Results
          if (_isSearching) ...[
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 56, color: AppTheme.lightTextSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No results found',
                            style: TextStyle(
                              color: AppTheme.lightTextSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _SearchResultsList(
                      results: _searchResults,
                      currentUserId:
                          Provider.of<AuthController>(context, listen: false)
                                  .currentUser
                                  ?.uid ??
                              '',
                      onTap: (chat) {
                        _clearSearch();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chat.chatId,
                              isGroup: chat.isGroup,
                              chatTitle: chat.isGroup
                                  ? (chat.groupName ?? 'Group Chat')
                                  : 'Chat',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],

          // Filter Chips (only show when not searching and not in archived view)
          if (!_isSearching && _selectedFilter != 'Archived') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Unread'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Favorites'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Groups'),
                  ],
                ),
              ),
            ),
          ],

          // Archived Folder (only show when not searching and in All filter)
          if (!_isSearching && _selectedFilter == 'All') ...[
            _buildArchivedFolder(),
          ],

          // Chat List (only show when not searching)
          if (!_isSearching) ...[
            Expanded(
              child: _ChatsTab(
                selectedFilter: _selectedFilter,
                searchQuery: _searchController.text,
                selectedChatIds: _selectedChatIds,
                isSelectionMode: _isSelectionMode,
                onSelectionToggle: _toggleChatSelection,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatScreen()),
          );
        },
        backgroundColor: AppTheme.lightPrimaryColor,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    final isArchivedView = _selectedFilter == 'Archived';

    return AppBar(
      backgroundColor: AppTheme.lightBackgroundColor,
      elevation: 0,
      leading: isArchivedView
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppTheme.lightTextPrimary,
              ),
              onPressed: () {
                setState(() {
                  _selectedFilter = 'All';
                });
              },
            )
          : null,
      title: Text(
        isArchivedView ? 'Archived' : 'Messenger',
        style: const TextStyle(
          color: AppTheme.lightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (!isArchivedView)
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.lightTextPrimary),
            onPressed: _showOptionsMenu,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final chatController = Provider.of<ChatController>(context, listen: false);

    // Check if all selected chats are pinned for icon display
    final selectedChats = chatController.chats
        .where((chat) => _selectedChatIds.contains(chat.chatId))
        .toList();
    final allPinned =
        selectedChats.isNotEmpty &&
        selectedChats.every((chat) => chat.isPinned);

    // Check if we're in archived view and all selected chats are archived
    final isArchivedView = _selectedFilter == 'Archived';
    final allArchived =
        selectedChats.isNotEmpty &&
        selectedChats.every((chat) => chat.isArchived);

    return AppBar(
      backgroundColor: AppTheme.lightBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
        onPressed: _clearSelection,
      ),
      title: Text(
        '${_selectedChatIds.length}',
        style: const TextStyle(
          color: AppTheme.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            allPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: AppTheme.lightTextPrimary,
          ),
          onPressed: _selectedChatIds.isNotEmpty ? _pinSelectedChats : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: AppTheme.lightErrorColor),
          onPressed: _selectedChatIds.isNotEmpty ? _deleteSelectedChats : null,
        ),
        // Show Unarchive button when in archived view or when all selected are archived
        IconButton(
          icon: Icon(
            isArchivedView || allArchived ? Icons.unarchive : Icons.archive,
            color: AppTheme.lightTextPrimary,
          ),
          onPressed: _selectedChatIds.isNotEmpty
              ? (isArchivedView || allArchived
                    ? _unarchiveSelectedChats
                    : _archiveSelectedChats)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppTheme.lightTextPrimary),
          onPressed: _showChatOptionsMenu,
        ),
      ],
    );
  }
}

class _ChatsTab extends StatefulWidget {
  final String selectedFilter;
  final String searchQuery;
  final Set<String> selectedChatIds;
  final bool isSelectionMode;
  final Function(String) onSelectionToggle;

  const _ChatsTab({
    required this.selectedFilter,
    required this.searchQuery,
    required this.selectedChatIds,
    required this.isSelectionMode,
    required this.onSelectionToggle,
  });

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-load contacts for ChatTile display name resolution
      Provider.of<ContactsController>(context, listen: false).loadContacts();
    });
  }

  List<ChatModel> _getFilteredChats(
    List<ChatModel> allChats,
    BuildContext context,
  ) {
    List<ChatModel> filteredChats = [];

    switch (widget.selectedFilter) {
      case 'All':
        // Show non-archived chats
        filteredChats = allChats.where((chat) => !chat.isArchived).toList();
        break;
      case 'Unread':
        // Show chats with unread messages (both individual and groups), excluding archived
        final currentUserId =
            Provider.of<AuthController>(
              context,
              listen: false,
            ).currentUser?.uid ??
            '';
        filteredChats = allChats.where((chat) {
          final unreadCount = chat.unreadCount[currentUserId] ?? 0;
          return unreadCount > 0 && !chat.isArchived;
        }).toList();
        break;
      case 'Favorites':
        // Show favorite chats, excluding archived
        filteredChats = allChats
            .where((chat) => chat.isFavorite && !chat.isArchived)
            .toList();
        break;
      case 'Groups':
        // Show only group chats, excluding archived
        filteredChats = allChats
            .where((chat) => chat.isGroup && !chat.isArchived)
            .toList();
        break;
      case 'Archived':
        // Show only archived chats
        filteredChats = allChats.where((chat) => chat.isArchived).toList();
        break;
    }

    // Apply search filter if query is not empty
    if (widget.searchQuery.isNotEmpty) {
      filteredChats = filteredChats.where((chat) {
        final searchLower = widget.searchQuery.toLowerCase();
        final chatName = chat.isGroup == true
            ? (chat.groupName ?? 'Group Chat').toLowerCase()
            : (chat.participants.isNotEmpty
                      ? chat.participants.first
                      : 'Unknown')
                  .toLowerCase();
        return chatName.contains(searchLower);
      }).toList();
    }

    // Sort: Pinned chats first, then by lastMessageTime (most recent first)
    filteredChats.sort((a, b) {
      // First sort by pinned status (pinned chats come first)
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // Then sort by last message time (most recent first)
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    return filteredChats;
  }

  String _getEmptyMessage() {
    switch (widget.selectedFilter) {
      case 'Favorites':
        return 'No favorite chats yet';
      case 'Groups':
        return 'No group chats yet';
      case 'Archived':
        return 'No archived chats';
      default:
        return 'No chats yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatController = Provider.of<ChatController>(context);

    // Get filtered chats
    final filteredChats = _getFilteredChats(chatController.chats, context);

    if (chatController.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.lightPrimaryColor),
        ),
      );
    }

    if (chatController.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.lightErrorColor,
            ),
            const SizedBox(height: 16),
            Text(
              chatController.errorMessage!,
              style: const TextStyle(
                color: AppTheme.lightErrorColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                chatController.clearError();
                chatController.listenToUserChats();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (filteredChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.lightTextSecondary,
            ),
            SizedBox(height: 16),
            Text(
              _getEmptyMessage(),
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return ChatTile(
          chat: chat,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chat.chatId,
                  isGroup: chat.isGroup,
                  chatTitle: chat.isGroup
                      ? (chat.groupName ?? 'Group Chat')
                      : 'Chat',
                ),
              ),
            );
          },
          isSelectionMode: widget.isSelectionMode,
          isSelected: widget.selectedChatIds.contains(chat.chatId),
          onSelectionToggle: widget.onSelectionToggle,
        );
      },
    );
  }
}

// ── Search Results Widget ──────────────────────────────────────────────────────
// Resolves real display names for 1-on-1 chats using AuthService + contacts

class _SearchResultsList extends StatefulWidget {
  final List<ChatModel> results;
  final String currentUserId;
  final void Function(ChatModel) onTap;

  const _SearchResultsList({
    required this.results,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  State<_SearchResultsList> createState() => _SearchResultsListState();
}

class _SearchResultsListState extends State<_SearchResultsList> {
  // Cache resolved names so we don't re-fetch on every rebuild
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _resolveNames();
  }

  @override
  void didUpdateWidget(_SearchResultsList old) {
    super.didUpdateWidget(old);
    if (old.results != widget.results) _resolveNames();
  }

  Future<void> _resolveNames() async {
    final contactsController =
        Provider.of<ContactsController>(context, listen: false);
    await contactsController.loadContacts();

    for (final chat in widget.results) {
      if (chat.isGroup) {
        _nameCache[chat.chatId] = chat.groupName ?? 'Group Chat';
        continue;
      }

      final otherUserId = chat.participants.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => '',
      );
      if (otherUserId.isEmpty) continue;
      if (_nameCache.containsKey(chat.chatId)) continue;

      try {
        final user = await AuthService().getUserById(otherUserId);
        if (user == null) continue;

        String name = user.name;
        if (user.phone != null && user.phone!.isNotEmpty) {
          try {
            final contact = contactsController.contacts.firstWhere(
              (c) =>
                  c.phone.replaceAll(RegExp(r'\D'), '') ==
                  user.phone!.replaceAll(RegExp(r'\D'), ''),
            );
            name = contact.name;
          } catch (_) {}
        }
        _nameCache[chat.chatId] = name;
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: widget.results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final chat = widget.results[index];
        final name = _nameCache[chat.chatId] ??
            (chat.isGroup ? (chat.groupName ?? 'Group Chat') : '...');
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.lightPrimaryColor,
            backgroundImage: chat.isGroup && chat.groupPhotoUrl != null
                ? NetworkImage(chat.groupPhotoUrl!)
                : null,
            child: (chat.isGroup && chat.groupPhotoUrl != null)
                ? null
                : (chat.isGroup
                    ? const Icon(Icons.group, color: Colors.white)
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          subtitle: chat.lastMessage.isNotEmpty
              ? Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.lightTextSecondary,
                  ),
                )
              : (chat.isGroup
                  ? Text(
                      '${chat.participants.length} members',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightTextSecondary,
                      ),
                    )
                  : null),
          onTap: () => widget.onTap(chat),
        );
      },
    );
  }
}
