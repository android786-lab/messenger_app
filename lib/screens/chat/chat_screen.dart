
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/block_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/chat_settings_controller.dart';
import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/message_bubble.dart';
import '../contacts/contact_info_screen.dart';
import '../group/group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isGroup;
  final String chatTitle;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.isGroup,
    required this.chatTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isComposing = false;
  String _displayName = '';
  bool _isLoadingName = true;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  MessageModel? _replyingTo;
  bool _isSearchMode = false;
  List<MessageModel> _searchResults = [];

  StreamSubscription? _onlineStatusSubscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatController = Provider.of<ChatController>(context, listen: false);
      chatController.listenToChatMessages(widget.chatId);
      chatController.markMessagesAsRead(widget.chatId);
      _loadDisplayName();
      _setupOnlineStatusListener();
    });
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final composing = _messageController.text.trim().isNotEmpty;
    if (composing != _isComposing) setState(() => _isComposing = composing);
    // Typing indicator
    final chatCtrl = Provider.of<ChatController>(context, listen: false);
    chatCtrl.setTyping(widget.chatId, composing);
    _typingTimer?.cancel();
    if (composing) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        chatCtrl.setTyping(widget.chatId, false);
      });
    }
  }

  void _setupOnlineStatusListener() {
    if (widget.isGroup) return;
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';
    String otherUserId = widget.chatId.split('_').first;
    if (otherUserId == currentUserId) otherUserId = widget.chatId.split('_').last;
    if (otherUserId.isEmpty) return;

    _onlineStatusSubscription =
        AuthService().streamUserById(otherUserId).listen((user) {
      if (user != null && mounted) {
        setState(() {
          _isOtherUserOnline = user.isOnline;
          _otherUserLastSeen = user.lastSeen;
        });
        if (user.isOnline) {
          final chatController =
              Provider.of<ChatController>(context, listen: false);
          final authCtrl = Provider.of<AuthController>(context, listen: false);
          final myId = authCtrl.currentUser?.uid ?? '';
          final messages = chatController.messages
              .where((m) => m.senderId == myId && m.status == 'sent')
              .toList();
          for (final m in messages) {
            ChatService()
                .updateMessageStatus(widget.chatId, m.messageId, 'delivered');
          }
        }
      }
    });
  }

  Future<void> _loadDisplayName() async {
    if (widget.isGroup) {
      setState(() {
        _displayName = widget.chatTitle;
        _isLoadingName = false;
      });
      return;
    }
    final authController = Provider.of<AuthController>(context, listen: false);
    final contactsController =
        Provider.of<ContactsController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';
    String otherUserId = widget.chatId.split('_').first;
    if (otherUserId == currentUserId) {
      otherUserId = widget.chatId.split('_').last;
    }
    if (otherUserId.isEmpty) {
      setState(() {
        _displayName = widget.chatTitle;
        _isLoadingName = false;
      });
      return;
    }
    await contactsController.loadContacts();
    final UserModel? user = await AuthService().getUserById(otherUserId);
    if (user != null) {
      String displayName = user.name;
      if (user.phone != null && user.phone!.isNotEmpty) {
        try {
          final contact = contactsController.contacts.firstWhere(
            (c) =>
                c.phone.replaceAll(RegExp(r'\D'), '') ==
                user.phone!.replaceAll(RegExp(r'\D'), ''),
          );
          displayName = contact.name;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _displayName = displayName;
          _isLoadingName = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _displayName = widget.chatTitle;
          _isLoadingName = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _onlineStatusSubscription?.cancel();
    _typingTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    // Clear typing on exit
    try {
      Provider.of<ChatController>(context, listen: false)
          .setTyping(widget.chatId, false);
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _statusText() {
    if (widget.isGroup) return '';
    // Stale-presence guard: if lastSeen > 5 min ago, treat as offline
    // even if isOnline flag wasn't cleared (e.g. app was force-killed)
    final isActuallyOnline = _isOtherUserOnline &&
        _otherUserLastSeen != null &&
        DateTime.now().difference(_otherUserLastSeen!).inMinutes < 5;

    if (isActuallyOnline) return 'Online';
    if (_otherUserLastSeen != null) {
      final diff = DateTime.now().difference(_otherUserLastSeen!);
      if (diff.inMinutes < 1) return 'last seen just now';
      if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
      return 'last seen ${diff.inDays}d ago';
    }
    return '';
  }

  // ── Send ──────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);
    final senderName = authController.currentUser?.name ?? 'Unknown';
    _messageController.clear();
    final reply = _replyingTo;
    setState(() {
      _isComposing = false;
      _replyingTo = null;
    });
    chatController.setTyping(widget.chatId, false);
    if (reply != null) {
      await chatController.sendReplyMessage(
        chatId: widget.chatId,
        content: text,
        senderName: senderName,
        replyToMessageId: reply.messageId,
        replyToSenderName: reply.senderName,
        replyToContent: reply.content,
        replyToType: reply.type,
      );
    } else {
      await chatController.sendTextMessage(
        chatId: widget.chatId,
        content: text,
        senderName: senderName,
      );
    }
    _scrollToBottom();
  }

  // ── Search ────────────────────────────────────────────────────

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final chatController = Provider.of<ChatController>(context, listen: false);
    final results = await chatController.searchMessages(widget.chatId, query);
    if (mounted) setState(() => _searchResults = results);
  }

  // ── Forward ───────────────────────────────────────────────────

  void _showForwardDialog(MessageModel message) {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);
    final senderName = authController.currentUser?.name ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollCtrl) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Forward to',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: chatController.chats.length,
                itemBuilder: (_, i) {
                  final chat = chatController.chats[i];
                  final name = chat.isGroup
                      ? (chat.groupName ?? 'Group')
                      : chat.chatId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.lightPrimaryColor,
                      child: Icon(
                          chat.isGroup ? Icons.group : Icons.person,
                          color: Colors.white),
                    ),
                    title: Text(name),
                    onTap: () async {
                      Navigator.pop(context);
                      await chatController.forwardMessage(
                        toChatId: chat.chatId,
                        content: message.content,
                        senderName: senderName,
                        originalSenderName: message.senderName,
                        type: message.type,
                        mediaUrl: message.mediaUrl,
                        fileName: message.fileName,
                        fileSize: message.fileSize,
                        fileExtension: message.fileExtension,
                        voiceDuration: message.voiceDuration,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Message forwarded')));
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attachments ───────────────────────────────────────────────

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera,
                  color: AppTheme.lightPrimaryColor),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _sendImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppTheme.lightPrimaryColor),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _sendImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file,
                  color: AppTheme.lightPrimaryColor),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageFromCamera() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final chat = Provider.of<ChatController>(context, listen: false);
    await chat.pickAndSendImageFromCamera(
        chatId: widget.chatId,
        senderName: auth.currentUser?.name ?? 'Unknown');
    _scrollToBottom();
  }

  Future<void> _sendImageFromGallery() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final chat = Provider.of<ChatController>(context, listen: false);
    await chat.pickAndSendImageFromGallery(
        chatId: widget.chatId,
        senderName: auth.currentUser?.name ?? 'Unknown');
    _scrollToBottom();
  }

  Future<void> _sendFile() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final chat = Provider.of<ChatController>(context, listen: false);
    await chat.pickAndSendFile(
        chatId: widget.chatId,
        senderName: auth.currentUser?.name ?? 'Unknown');
    _scrollToBottom();
  }

  // ── Voice recording ───────────────────────────────────────────

  Widget _buildVoiceRecordingButton() {
    return Consumer<ChatController>(
      builder: (context, chatController, _) {
        if (chatController.isRecording) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.lightErrorColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(_formatDuration(chatController.recordingDuration),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final auth =
                        Provider.of<AuthController>(context, listen: false);
                    await chatController.stopRecording();
                    await chatController.sendVoiceMessage(
                        chatId: widget.chatId,
                        senderName: auth.currentUser?.name ?? 'Unknown');
                    _scrollToBottom();
                  },
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
            ),
          );
        }
        return GestureDetector(
          onTap: () => chatController.startRecording(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppTheme.lightPrimaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 18),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  // ── Navigation ────────────────────────────────────────────────

  void _openViewInfo() {
    if (widget.isGroup) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => GroupInfoScreen(
                    chatId: widget.chatId,
                    groupName:
                        _isLoadingName ? widget.chatTitle : _displayName,
                  )));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContactInfoScreen(
                    chatId: widget.chatId,
                    displayName:
                        _isLoadingName ? widget.chatTitle : _displayName,
                    isGroup: false,
                  )));
    }
  }

  // ── Disappearing messages dialog ──────────────────────────────

  void _showDisappearingDialog() {
    final options = [
      {'label': 'Off', 'seconds': 0},
      {'label': '24 hours', 'seconds': 86400},
      {'label': '7 days', 'seconds': 604800},
      {'label': '90 days', 'seconds': 7776000},
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Disappearing messages',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...options.map((o) => ListTile(
                  title: Text(o['label'] as String),
                  onTap: () async {
                    Navigator.pop(context);
                    await Provider.of<ChatController>(context, listen: false)
                        .setDisappearingMessages(
                            widget.chatId, o['seconds'] as int);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Disappearing messages: ${o['label']}')));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUserId = authController.currentUser?.uid ?? '';
    final chatSettings = Provider.of<ChatSettingsController>(context);

    return Scaffold(
      backgroundColor: chatSettings.wallpaperColor,
      appBar: _isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          // ── Pinned message banner ──────────────────────────────
          Consumer<ChatController>(
            builder: (context, chatController, _) {
              final pinned = chatController.messages
                  .where((m) => m.isPinned && m.type != 'deleted')
                  .toList();
              if (pinned.isEmpty) return const SizedBox.shrink();
              final latest = pinned.first;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(
                          color: Color(0xFFE4E6EB), width: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin,
                        size: 16, color: AppTheme.lightPrimaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pinned message',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.lightPrimaryColor,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            latest.type == 'image'
                                ? '📷 Photo'
                                : latest.type == 'voice'
                                    ? '🎤 Voice message'
                                    : latest.type == 'file'
                                        ? '📎 ${latest.fileName ?? "File"}'
                                        : latest.content,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.lightTextSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 16,
                          color: AppTheme.lightTextSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          Provider.of<ChatController>(context, listen: false)
                              .unpinMessage(widget.chatId, latest.messageId),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Typing indicator ───────────────────────────────────
          if (!widget.isGroup)
            StreamBuilder<List<String>>(
              stream: Provider.of<ChatController>(context, listen: false)
                  .getTypingUsers(widget.chatId),
              builder: (context, snapshot) {
                final typingUsers = snapshot.data ?? [];
                if (typingUsers.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildTypingDots(),
                      const SizedBox(width: 8),
                      Text('typing...',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.lightTextSecondary,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                );
              },
            ),

          // ── Search results ─────────────────────────────────────
          if (_isSearchMode && _searchResults.isNotEmpty)
            Container(
              height: 200,
              color: Colors.white,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final msg = _searchResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(msg.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        msg.senderName,
                        style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      setState(() => _isSearchMode = false);
                    },
                  );
                },
              ),
            ),

          // ── Messages list ──────────────────────────────────────
          Expanded(
            child: Consumer<ChatController>(
              builder: (context, chatController, _) {
                if (chatController.isLoading &&
                    chatController.messages.isEmpty) {
                  return const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.lightPrimaryColor)));
                }
                if (chatController.messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64,
                            color: AppTheme.lightTextSecondary),
                        SizedBox(height: 16),
                        Text('No messages yet',
                            style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.lightTextSecondary,
                                fontWeight: FontWeight.w500)),
                        SizedBox(height: 8),
                        Text('Send a message to start the conversation',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.lightTextSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: chatController.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatController.messages[index];
                    final isMe = message.senderId == currentUserId;
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      chatId: widget.chatId,
                      currentUserId: currentUserId,
                      fontSize: chatSettings.fontSize,
                      onReply: (msg) =>
                          setState(() => _replyingTo = msg),
                      onForward: _showForwardDialog,
                    );
                  },
                );
              },
            ),
          ),

          // ── Reply preview bar ──────────────────────────────────
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(
                        color: Color(0xFFE4E6EB), width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                      width: 3,
                      height: 40,
                      color: AppTheme.lightPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_replyingTo!.senderName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.lightPrimaryColor)),
                        Text(
                          _replyingTo!.type == 'image'
                              ? '📷 Photo'
                              : _replyingTo!.type == 'voice'
                                  ? '🎤 Voice message'
                                  : _replyingTo!.content,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.lightTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // ── Input bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.lightBackgroundColor,
              border: Border(
                  top: BorderSide(
                      color: Color(0xFFE4E6EB), width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.add,
                      color: AppTheme.lightPrimaryColor, size: 24),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: _showAttachmentOptions,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE4E6EB)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: AppTheme.lightTextSecondary,
                            fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 15),
                      maxLines: null,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isComposing
                    ? GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppTheme.lightPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 18),
                        ),
                      )
                    : _buildVoiceRecordingButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBars ────────────────────────────────────────────────────

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: AppTheme.lightBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: GestureDetector(
        onTap: _openViewInfo,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.lightPrimaryColor,
              child: widget.isGroup
                  ? const Icon(Icons.group, color: Colors.white)
                  : Text(
                      _displayName.isNotEmpty
                          ? _displayName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoadingName ? widget.chatTitle : _displayName,
                    style: const TextStyle(
                      color: AppTheme.lightTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!widget.isGroup)
                    Text(
                      _statusText(),
                      style: TextStyle(
                        color: _isOtherUserOnline
                            ? Colors.green
                            : AppTheme.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppTheme.lightTextPrimary),
          onPressed: () => setState(() => _isSearchMode = true),
        ),
        IconButton(
          icon: const Icon(Icons.videocam, color: AppTheme.lightTextPrimary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call, color: AppTheme.lightTextPrimary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppTheme.lightTextPrimary),
          onPressed: _showChatOptions,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: AppTheme.lightBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
        onPressed: () {
          setState(() {
            _isSearchMode = false;
            _searchResults = [];
            _searchController.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search messages...',
          border: InputBorder.none,
          hintStyle:
              TextStyle(color: AppTheme.lightTextSecondary, fontSize: 15),
        ),
        style: const TextStyle(
            fontSize: 15, color: AppTheme.lightTextPrimary),
        onChanged: _performSearch,
      ),
    );
  }

  // ── Typing dots animation ─────────────────────────────────────

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          3,
          (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.lightTextSecondary,
                  shape: BoxShape.circle,
                ),
              )),
    );
  }

  // ── Add member to group ────────────────────────────────────────

  void _showAddMemberSheet() {
    final chatService = ChatService();
    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);

    // Get current participants from the chats list
    final currentChat = chatController.chats
        .where((c) => c.chatId == widget.chatId)
        .firstOrNull;
    final currentParticipants =
        List<String>.from(currentChat?.participants ?? []);

    final searchCtrl = TextEditingController();
    List<dynamic> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, scrollCtrl) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              children: [
                const Text('Add Member',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (q) async {
                    if (q.trim().isEmpty) {
                      setModal(() => results = []);
                      return;
                    }
                    setModal(() => searching = true);
                    final found =
                        await authController.searchUsers(q.trim());
                    setModal(() {
                      results = found
                          .where((u) =>
                              !currentParticipants.contains(u.uid))
                          .toList();
                      searching = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: searching
                      ? const Center(child: CircularProgressIndicator())
                      : results.isEmpty
                          ? Center(
                              child: Text(
                                searchCtrl.text.isEmpty
                                    ? 'Search for users to add'
                                    : 'No users found',
                                style: const TextStyle(
                                    color: AppTheme.lightTextSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: results.length,
                              itemBuilder: (_, i) {
                                final u = results[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppTheme.lightPrimaryColor,
                                    backgroundImage: u.photoUrl != null
                                        ? NetworkImage(u.photoUrl!)
                                        : null,
                                    child: u.photoUrl == null
                                        ? Text(
                                            u.name.isNotEmpty
                                                ? u.name[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  title: Text(u.name),
                                  subtitle: Text(u.email),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add,
                                        color: AppTheme.lightPrimaryColor),
                                    onPressed: () async {
                                      await chatService.addMemberToGroup(
                                          widget.chatId, u.uid);
                                      currentParticipants.add(u.uid);
                                      setModal(() => results.removeWhere(
                                          (r) => r.uid == u.uid));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              '${u.name} added to group'),
                                        ));
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Options bottom sheet ───────────────────────────────────────

  void _showChatOptions() {
    final chatController =
        Provider.of<ChatController>(context, listen: false);
    final chat = chatController.chats
        .where((c) => c.chatId == widget.chatId)
        .firstOrNull;
    final authController =
        Provider.of<AuthController>(context, listen: false);
    final isMuted =
        chat?.mutedBy.contains(authController.currentUser?.uid) ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info,
                  color: AppTheme.lightPrimaryColor),
              title: const Text('View Info'),
              onTap: () {
                Navigator.pop(context);
                _openViewInfo();
              },
            ),
            // "Add Member" only in group chats — adds a new member to the group
            if (widget.isGroup)
              ListTile(
                leading: const Icon(Icons.person_add,
                    color: AppTheme.lightPrimaryColor),
                title: const Text('Add Member'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddMemberSheet();
                },
              ),
            ListTile(
              leading: Icon(
                isMuted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: AppTheme.lightPrimaryColor,
              ),
              title: Text(isMuted ? 'Unmute' : 'Mute notifications'),
              onTap: () async {
                Navigator.pop(context);
                await chatController.muteChatForUser(
                    widget.chatId, !isMuted);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isMuted
                          ? 'Notifications unmuted'
                          : 'Notifications muted')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined,
                  color: AppTheme.lightPrimaryColor),
              title: const Text('Disappearing messages'),
              onTap: () {
                Navigator.pop(context);
                _showDisappearingDialog();
              },
            ),
            if (!widget.isGroup)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockDialog();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
            'Are you sure you want to block ${_isLoadingName ? widget.chatTitle : _displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final blockController =
                  Provider.of<BlockController>(context, listen: false);
              final authController =
                  Provider.of<AuthController>(context, listen: false);
              String otherUserId = widget.chatId.split('_').first;
              if (otherUserId == authController.currentUser?.uid) {
                otherUserId = widget.chatId.split('_').last;
              }
              final success = await blockController.blockUser(otherUserId);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${_isLoadingName ? widget.chatTitle : _displayName} has been blocked'),
                    backgroundColor: Colors.green));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Block',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
