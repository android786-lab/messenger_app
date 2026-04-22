import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/contacts_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_formatter.dart';
import '../models/chat_model.dart';
import '../models/local_contact_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class ChatTile extends StatefulWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String)? onSelectionToggle;

  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  @override
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile> {
  List<LocalContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
    });
  }

  Future<void> _loadContacts() async {
    final contactsController = Provider.of<ContactsController>(
      context,
      listen: false,
    );
    await contactsController.loadContacts();
    if (mounted) {
      setState(() {
        _contacts = contactsController.contacts;
      });
    }
  }

  String? _findContactNameByPhone(String phone) {
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    for (final contact in _contacts) {
      final contactNormalized = contact.phone.replaceAll(RegExp(r'\D'), '');
      if (contactNormalized == normalizedPhone) {
        return contact.name;
      }
    }
    return null;
  }

  Widget _buildChatTitle(String currentUserId) {
    if (widget.chat.isGroup) {
      return Text(
        widget.chat.groupName ?? 'Group Chat',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.lightTextPrimary,
        ),
        overflow: TextOverflow.ellipsis,
      );
    } else {
      // For one-to-one chat, get other user's ID and fetch their details
      String otherUserId = widget.chat.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) {
        return const Text(
          'User',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTextPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }

      return FutureBuilder<UserModel?>(
        future: AuthService().getUserById(otherUserId),
        builder: (context, snapshot) {
          String displayName = 'User';

          if (snapshot.hasData && snapshot.data != null) {
            final user = snapshot.data!;
            // Try to find contact name by phone
            if (user.phone != null && user.phone!.isNotEmpty) {
              final contactName = _findContactNameByPhone(user.phone!);
              displayName = contactName ?? user.name;
            } else {
              displayName = user.name;
            }
          }

          return Text(
            displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUserId = authController.currentUser?.uid ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isSelectionMode
            ? () => widget.onSelectionToggle?.call(widget.chat.chatId)
            : widget.onTap,
        onLongPress: widget.isSelectionMode
            ? null
            : () {
                // Enter selection mode on long press
                widget.onSelectionToggle?.call(widget.chat.chatId);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.lightPrimaryColor.withValues(alpha: 0.1)
                : null,
          ),
          child: Row(
            children: [
              if (widget.isSelectionMode) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: (bool? value) =>
                      widget.onSelectionToggle?.call(widget.chat.chatId),
                  activeColor: AppTheme.lightPrimaryColor,
                ),
                const SizedBox(width: 12),
              ],
              _buildAvatar(currentUserId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildChatTitle(currentUserId)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              TimeFormatter.formatChatListTime(
                                widget.chat.lastMessageTime,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasUnreadMessages(currentUserId)
                                    ? AppTheme.lightPrimaryColor
                                    : AppTheme.lightTextSecondary,
                                fontWeight: _hasUnreadMessages(currentUserId)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (widget.chat.isPinned) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.push_pin,
                                size: 16,
                                color: AppTheme.lightTextSecondary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLastMessageWithStatus(currentUserId),
                        ),
                        if (_hasUnreadMessages(currentUserId))
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.lightPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getUnreadCount(currentUserId).toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String currentUserId) {
    if (widget.chat.isGroup) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: AppTheme.lightPrimaryColor,
        backgroundImage: widget.chat.groupPhotoUrl != null
            ? NetworkImage(widget.chat.groupPhotoUrl!)
            : null,
        child: widget.chat.groupPhotoUrl == null
            ? const Icon(Icons.group, color: Colors.white, size: 28)
            : null,
      );
    } else {
      // For one-to-one chat, show other user's avatar
      String otherUserId = widget.chat.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      // Use StreamBuilder for real-time online status updates
      return StreamBuilder<UserModel?>(
        stream: AuthService().streamUserById(otherUserId),
        builder: (context, snapshot) {
          UserModel? otherUser = snapshot.data;
          final isOnline = otherUser?.isOnline == true;

          return Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.lightPrimaryColor,
                backgroundImage: otherUser?.photoUrl != null
                    ? NetworkImage(otherUser!.photoUrl!)
                    : null,
                child: otherUser?.photoUrl == null
                    ? Text(
                        otherUser?.name.isNotEmpty == true
                            ? otherUser!.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
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
          );
        },
      );
    }
  }

  String _getLastMessageText() {
    if (widget.chat.lastMessage.isEmpty) {
      return 'No messages yet';
    }

    switch (widget.chat.lastMessageType) {
      case AppConstants.imageMessage:
        return '📷 Photo';
      case AppConstants.voiceMessage:
        return '🎵 Voice message';
      default:
        return widget.chat.lastMessage;
    }
  }

  bool _hasUnreadMessages(String currentUserId) {
    return (widget.chat.unreadCount[currentUserId] ?? 0) > 0;
  }

  int _getUnreadCount(String currentUserId) {
    return widget.chat.unreadCount[currentUserId] ?? 0;
  }

  Widget _buildLastMessageWithStatus(String currentUserId) {
    // Check if current user is the sender of the last message
    final isLastMessageFromMe =
        widget.chat.lastMessageSenderId == currentUserId;

    return Row(
      children: [
        if (isLastMessageFromMe) ...[
          // Show message status ticks - use StreamBuilder for real-time status
          _buildMessageStatusStream(),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            _getLastMessageText(),
            style: TextStyle(
              fontSize: 14,
              color: _hasUnreadMessages(currentUserId)
                  ? AppTheme.lightTextPrimary
                  : AppTheme.lightTextSecondary,
              fontWeight: _hasUnreadMessages(currentUserId)
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageStatusStream() {
    // Stream the last message to get real-time status updates
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        String status = 'sent';

        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          if (docs.isNotEmpty) {
            final data = docs.first.data() as Map<String, dynamic>;
            status = data['status'] ?? 'sent';
          }
        }

        return _buildMessageStatusTicks(status);
      },
    );
  }

  Widget _buildMessageStatusTicks(String status) {
    // Determine tick color based on status
    final tickColor = status == 'read'
        ? const Color(0xFF53BDEB) // Light blue for read
        : AppTheme.lightTextSecondary;

    // Single tick for sent
    if (status == 'sent') {
      return const Icon(
        Icons.check,
        size: 14,
        color: AppTheme.lightTextSecondary,
      );
    }

    // Double ticks for delivered or read
    return SizedBox(
      width: 20,
      height: 14,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Icon(Icons.check, size: 14, color: tickColor),
          ),
          Positioned(
            left: 4,
            child: Icon(Icons.check, size: 14, color: tickColor),
          ),
        ],
      ),
    );
  }
}
