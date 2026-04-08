import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/block_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/message_bubble.dart';
import '../contacts/add_contact_screen.dart';

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
  bool _isComposing = false;
  String _displayName = '';
  bool _isLoadingName = true;
  String? _otherUserId;
  StreamSubscription<bool>? _onlineStatusSubscription;

  @override
  void initState() {
    super.initState();

    // Start listening to messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatController = Provider.of<ChatController>(
        context,
        listen: false,
      );
      chatController.listenToChatMessages(widget.chatId);
      chatController.markMessagesAsRead(widget.chatId);
      _loadDisplayName();
      _setupOnlineStatusListener();
    });

    _messageController.addListener(() {
      setState(() {
        _isComposing = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  void _setupOnlineStatusListener() {
    if (widget.isGroup) return;

    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';

    // Extract other user ID from chat ID (format: user1_user2)
    String otherUserId = widget.chatId.split('_').first;
    if (otherUserId == currentUserId) {
      otherUserId = widget.chatId.split('_').last;
    }

    if (otherUserId.isEmpty) return;
    _otherUserId = otherUserId;

    // Listen for other user's online status changes
    _onlineStatusSubscription = ChatService().isUserOnline(otherUserId).listen((
      isOnline,
    ) {
      if (isOnline) {
        // When other user comes online, update 'sent' messages to 'delivered'
        _updateMessagesToDelivered();
      }
    });
  }

  void _updateMessagesToDelivered() {
    final chatController = Provider.of<ChatController>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUserId = authController.currentUser?.uid ?? '';

    // Get messages sent by current user with 'sent' status
    final messages = chatController.messages
        .where((msg) => msg.senderId == currentUserId && msg.status == 'sent')
        .toList();

    // Update each message to 'delivered'
    for (final message in messages) {
      ChatService().updateMessageStatus(
        widget.chatId,
        message.messageId,
        'delivered',
      );
    }
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
    final contactsController = Provider.of<ContactsController>(
      context,
      listen: false,
    );
    final currentUserId = authController.currentUser?.uid ?? '';

    // Extract other user ID from chat ID (format: user1_user2)
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

    // Load contacts
    await contactsController.loadContacts();

    // Get user details
    final UserModel? user = await AuthService().getUserById(otherUserId);

    if (user != null) {
      // Try to find contact name by phone
      String displayName = user.name;
      if (user.phone != null && user.phone!.isNotEmpty) {
        try {
          final contact = contactsController.contacts.firstWhere(
            (c) =>
                c.phone.replaceAll(RegExp(r'\D'), '') ==
                user.phone!.replaceAll(RegExp(r'\D'), ''),
          );
          displayName = contact.name;
        } catch (e) {
          // Contact not found, use user name
        }
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);

    String message = _messageController.text.trim();
    _messageController.clear();
    setState(() {
      _isComposing = false;
    });

    await chatController.sendTextMessage(
      chatId: widget.chatId,
      content: message,
      senderName: authController.currentUser?.name ?? 'Unknown',
    );

    _scrollToBottom();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera,
                color: AppTheme.lightPrimaryColor,
              ),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _sendImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.lightPrimaryColor,
              ),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _sendImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.attach_file,
                color: AppTheme.lightPrimaryColor,
              ),
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
    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);

    await chatController.pickAndSendImageFromCamera(
      chatId: widget.chatId,
      senderName: authController.currentUser?.name ?? 'Unknown',
    );

    _scrollToBottom();
  }

  Future<void> _sendImageFromGallery() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);

    await chatController.pickAndSendImageFromGallery(
      chatId: widget.chatId,
      senderName: authController.currentUser?.name ?? 'Unknown',
    );

    _scrollToBottom();
  }

  Future<void> _sendFile() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final chatController = Provider.of<ChatController>(context, listen: false);

    await chatController.pickAndSendFile(
      chatId: widget.chatId,
      senderName: authController.currentUser?.name ?? 'Unknown',
    );

    _scrollToBottom();
  }

  Widget _buildVoiceRecordingButton() {
    return Consumer<ChatController>(
      builder: (context, chatController, child) {
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
                Text(
                  _formatDuration(chatController.recordingDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final authController = Provider.of<AuthController>(
                      context,
                      listen: false,
                    );
                    await chatController.stopRecording();
                    await chatController.sendVoiceMessage(
                      chatId: widget.chatId,
                      senderName: authController.currentUser?.name ?? 'Unknown',
                    );
                    _scrollToBottom();
                  },
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            chatController.startRecording();
          },
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUserId = authController.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    const Text(
                      'Online', // You can enhance this with real online status
                      style: TextStyle(
                        color: AppTheme.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: AppTheme.lightTextPrimary),
            onPressed: () {
              // TODO: Implement video call
            },
          ),
          IconButton(
            icon: const Icon(Icons.call, color: AppTheme.lightTextPrimary),
            onPressed: () {
              // TODO: Implement voice call
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.lightTextPrimary),
            onPressed: () => _showChatOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<ChatController>(
              builder: (context, chatController, child) {
                if (chatController.isLoading &&
                    chatController.messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.lightPrimaryColor,
                      ),
                    ),
                  );
                }

                if (chatController.messages.isEmpty) {
                  return const Center(
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
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.lightTextSecondary,
                          ),
                        ),
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

                    return MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.lightBackgroundColor,
              border: Border(
                top: BorderSide(color: Color(0xFFE4E6EB), width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Attachment Button
                IconButton(
                  icon: const Icon(
                    Icons.add,
                    color: AppTheme.lightPrimaryColor,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: _showAttachmentOptions,
                ),

                const SizedBox(width: 4),

                // Message Input Field
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 15),
                      maxLines: null,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) {
                        setState(() {
                          _isComposing = value.trim().isNotEmpty;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send Button or Voice Recording
                _isComposing
                    ? GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppTheme.lightPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
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

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.person_add,
                color: AppTheme.lightPrimaryColor,
              ),
              title: const Text('Add Contact'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddContactScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.info,
                color: AppTheme.lightPrimaryColor,
              ),
              title: const Text('View Info'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement view info
              },
            ),
            if (!widget.isGroup) ...[
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockDialog();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement report
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
          'Are you sure you want to block ${_isLoadingName ? widget.chatTitle : _displayName}? You will no longer receive messages from them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final blockController = Provider.of<BlockController>(
                context,
                listen: false,
              );

              // Extract user ID from chat ID (for 1-on-1 chats)
              String otherUserId = widget.chatId.split('_').first;
              if (otherUserId ==
                  Provider.of<AuthController>(
                    context,
                    listen: false,
                  ).currentUser?.uid) {
                otherUserId = widget.chatId.split('_').last;
              }

              bool success = await blockController.blockUser(otherUserId);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_isLoadingName ? widget.chatTitle : _displayName} has been blocked',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
