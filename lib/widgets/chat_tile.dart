import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/contacts_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_formatter.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// A single row in the chat list.
///
/// Performance notes:
/// - User data is fetched once in initState and cached — no FutureBuilder on rebuild.
/// - Online status uses a single persistent stream, not a new one per build.
/// - Message status is read from ChatModel.lastMessage (already in memory) — no extra Firestore stream.
/// - Contacts are read from the shared ContactsController cache — no per-tile Firestore reads.
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
  UserModel? _otherUser;
  String _displayName = '';
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    if (!widget.chat.isGroup) {
      _initUser();
    }
  }

  @override
  void didUpdateWidget(ChatTile old) {
    super.didUpdateWidget(old);
    // Re-fetch if the chat changed (e.g. participants updated)
    if (!widget.chat.isGroup &&
        old.chat.chatId != widget.chat.chatId) {
      _initUser();
    }
  }

  Future<void> _initUser() async {
    final authController =
        Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';

    final otherUserId = widget.chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) return;

    // Single fetch — result is cached in state
    final user = await AuthService().getUserById(otherUserId);
    if (!mounted || user == null) return;

    // Resolve display name from saved contacts (already in memory)
    final contactsController =
        Provider.of<ContactsController>(context, listen: false);
    String name = user.name;
    if (user.phone != null && user.phone!.isNotEmpty) {
      final normalized = user.phone!.replaceAll(RegExp(r'\D'), '');
      try {
        final contact = contactsController.contacts.firstWhere(
          (c) => c.phone.replaceAll(RegExp(r'\D'), '') == normalized,
        );
        name = contact.name;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _otherUser = user;
        _displayName = name;
        _isOnline = user.isOnline;
      });
    }

    // Stream online status updates — one persistent listener per tile
    AuthService().streamUserById(otherUserId).listen((u) {
      if (mounted && u != null) {
        setState(() {
          _otherUser = u;
          _isOnline = u.isOnline;
        });
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────

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
            : () => widget.onSelectionToggle?.call(widget.chat.chatId),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: widget.isSelected
              ? AppTheme.lightPrimaryColor.withValues(alpha: 0.1)
              : null,
          child: Row(
            children: [
              if (widget.isSelectionMode) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: (_) =>
                      widget.onSelectionToggle?.call(widget.chat.chatId),
                  activeColor: AppTheme.lightPrimaryColor,
                ),
                const SizedBox(width: 12),
              ],
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildTitle()),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              TimeFormatter.formatChatListTime(
                                  widget.chat.lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasUnread(currentUserId)
                                    ? AppTheme.lightPrimaryColor
                                    : AppTheme.lightTextSecondary,
                                fontWeight: _hasUnread(currentUserId)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (widget.chat.isPinned) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.push_pin,
                                  size: 14,
                                  color: AppTheme.lightTextSecondary),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                            child: _buildLastMessage(currentUserId)),
                        if (_hasUnread(currentUserId))
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppTheme.lightPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _unreadCount(currentUserId).toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
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

  // ── Avatar ─────────────────────────────────────────────────────

  Widget _buildAvatar() {
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
    }

    final photoUrl = _otherUser?.photoUrl;
    final initial = _displayName.isNotEmpty
        ? _displayName[0].toUpperCase()
        : (_otherUser?.name.isNotEmpty == true
            ? _otherUser!.name[0].toUpperCase()
            : 'U');

    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.lightPrimaryColor,
          backgroundImage:
              photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        if (_isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  // ── Title ──────────────────────────────────────────────────────

  Widget _buildTitle() {
    final name = widget.chat.isGroup
        ? (widget.chat.groupName ?? 'Group Chat')
        : (_displayName.isNotEmpty ? _displayName : '...');

    return Text(
      name,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.lightTextPrimary),
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Last message ───────────────────────────────────────────────

  Widget _buildLastMessage(String currentUserId) {
    final isFromMe =
        widget.chat.lastMessageSenderId == currentUserId;
    final hasUnread = _hasUnread(currentUserId);

    return Row(
      children: [
        if (isFromMe) ...[
          _buildStatusTick(),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            _lastMessageText(),
            style: TextStyle(
              fontSize: 14,
              color: hasUnread
                  ? AppTheme.lightTextPrimary
                  : AppTheme.lightTextSecondary,
              fontWeight:
                  hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  String _lastMessageText() {
    if (widget.chat.lastMessage.isEmpty) return 'No messages yet';
    switch (widget.chat.lastMessageType) {
      case AppConstants.imageMessage:
        return '📷 Photo';
      case AppConstants.voiceMessage:
        return '🎵 Voice message';
      case AppConstants.fileMessage:
        return '📎 File';
      default:
        return widget.chat.lastMessage;
    }
  }

  /// Status ticks derived from ChatModel — no extra Firestore stream needed.
  Widget _buildStatusTick() {
    // We use the lastMessage status stored in the chat doc itself.
    // The chat doc's lastMessageType already tells us the type;
    // for status we rely on the unread count heuristic:
    // if all other participants have 0 unread → read, else delivered/sent.
    // This avoids an extra per-tile Firestore stream.
    final allRead = widget.chat.participants.every((uid) {
      if (uid == widget.chat.lastMessageSenderId) return true;
      return (widget.chat.unreadCount[uid] ?? 0) == 0;
    });

    final color = allRead
        ? const Color(0xFF53BDEB)
        : AppTheme.lightTextSecondary;

    return SizedBox(
      width: 20,
      height: 14,
      child: Stack(
        children: [
          Positioned(
              left: 0,
              child: Icon(Icons.check, size: 14, color: color)),
          Positioned(
              left: 4,
              child: Icon(Icons.check, size: 14, color: color)),
        ],
      ),
    );
  }

  bool _hasUnread(String uid) =>
      (widget.chat.unreadCount[uid] ?? 0) > 0;
  int _unreadCount(String uid) =>
      widget.chat.unreadCount[uid] ?? 0;
}
