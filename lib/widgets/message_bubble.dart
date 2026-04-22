import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_formatter.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String chatId;
  final String currentUserId;
  final void Function(MessageModel)? onReply;
  final void Function(MessageModel)? onForward;
  final double fontSize;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatId,
    required this.currentUserId,
    this.onReply,
    this.onForward,
    this.fontSize = 15,
  });

  // ── Reaction picker ────────────────────────────────────────────

  void _showReactionPicker(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) {
        final chatCtrl = Provider.of<ChatController>(context, listen: false);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: emojis.map((e) {
                final alreadyReacted =
                    message.reactions[e]?.contains(currentUserId) ?? false;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    if (alreadyReacted) {
                      await chatCtrl.removeReaction(
                          chatId, message.messageId, e);
                    } else {
                      await chatCtrl.addReaction(
                          chatId, message.messageId, e);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(e,
                        style: TextStyle(
                            fontSize: alreadyReacted ? 28 : 22)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ── Long-press menu ────────────────────────────────────────────

  void _showMessageOptions(BuildContext context) {
    final isDeleted = message.type == 'deleted';
    final isPinned = message.isPinned;
    final isStarred = message.isStarred;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final chatCtrl = Provider.of<ChatController>(context, listen: false);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // React
              if (!isDeleted)
                ListTile(
                  leading: const Icon(Icons.emoji_emotions_outlined,
                      color: AppTheme.lightPrimaryColor),
                  title: const Text('React'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReactionPicker(context);
                  },
                ),

              // Reply
              if (!isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply_outlined,
                      color: AppTheme.lightPrimaryColor),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onReply?.call(message);
                  },
                ),

              // Forward
              if (!isDeleted)
                ListTile(
                  leading: const Icon(Icons.forward_outlined,
                      color: AppTheme.lightPrimaryColor),
                  title: const Text('Forward'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onForward?.call(message);
                  },
                ),

              // Star / Unstar
              if (!isDeleted)
                ListTile(
                  leading: Icon(
                    isStarred ? Icons.star : Icons.star_border_outlined,
                    color: isStarred
                        ? Colors.amber
                        : AppTheme.lightPrimaryColor,
                  ),
                  title:
                      Text(isStarred ? 'Unstar message' : 'Star message'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await chatCtrl.toggleStarMessage(
                        chatId, message.messageId, !isStarred);
                  },
                ),

              // Pin / Unpin
              if (!isDeleted)
                ListTile(
                  leading: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: AppTheme.lightPrimaryColor,
                  ),
                  title: Text(
                      isPinned ? 'Unpin message' : 'Pin message'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (isPinned) {
                      await chatCtrl.unpinMessage(
                          chatId, message.messageId);
                    } else {
                      await chatCtrl.pinMessage(
                          chatId, message.messageId);
                    }
                  },
                ),

              // Copy
              if (!isDeleted &&
                  message.type == AppConstants.textMessage)
                ListTile(
                  leading: const Icon(Icons.copy_outlined,
                      color: AppTheme.lightPrimaryColor),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(
                        ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Message copied'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),

              // Delete
              if (!isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  title: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteOptions(context, chatCtrl);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteOptions(BuildContext context, ChatController chatCtrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message'),
        content:
            const Text('Who do you want to delete this message for?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await chatCtrl.deleteMessageForMe(
                  chatId, message.messageId);
            },
            child: const Text('Delete for me'),
          ),
          if (isMe)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await chatCtrl.deleteMessageForEveryone(
                    chatId, message.messageId);
              },
              child: const Text('Delete for everyone',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (message.deletedFor.contains(currentUserId)) {
      return const SizedBox.shrink();
    }

    // Hide expired disappearing messages
    if (message.expiresAt != null &&
        DateTime.now().isAfter(message.expiresAt!)) {
      return const SizedBox.shrink();
    }

    final isDeleted = message.type == 'deleted';

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) _buildAvatar(),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDeleted
                          ? Colors.grey[200]
                          : (isMe
                              ? AppTheme.chatBubbleMe
                              : AppTheme.chatBubbleOther),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Forwarded label
                        if (message.forwardedFrom != null && !isDeleted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forward,
                                    size: 13,
                                    color: isMe
                                        ? Colors.white70
                                        : AppTheme.lightTextSecondary),
                                const SizedBox(width: 4),
                                Text('Forwarded',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: isMe
                                          ? Colors.white70
                                          : AppTheme.lightTextSecondary,
                                    )),
                              ],
                            ),
                          ),

                        // Sender name (groups)
                        if (!isMe &&
                            message.senderName.isNotEmpty &&
                            !isDeleted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              message.senderName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.lightPrimaryColor,
                              ),
                            ),
                          ),

                        // Reply preview
                        if (message.replyTo != null && !isDeleted)
                          _buildReplyPreview(),

                        // Content
                        _buildMessageContent(context, isDeleted),

                        const SizedBox(height: 4),

                        // Timestamp + status
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isStarred && !isDeleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.star,
                                    size: 11,
                                    color: isMe
                                        ? Colors.amber[200]
                                        : Colors.amber),
                              ),
                            if (message.isPinned && !isDeleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin,
                                    size: 11,
                                    color: isMe
                                        ? Colors.white70
                                        : AppTheme.lightTextSecondary),
                              ),
                            if (message.expiresAt != null && !isDeleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.timer_outlined,
                                    size: 11,
                                    color: isMe
                                        ? Colors.white70
                                        : AppTheme.lightTextSecondary),
                              ),
                            Text(
                              TimeFormatter.formatMessageTime(
                                  message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                            if (isMe && !isDeleted) ...[
                              const SizedBox(width: 4),
                              _buildMessageStatus(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isMe) _buildAvatar(),
              ],
            ),

            // Reactions row
            if (message.reactions.isNotEmpty && !isDeleted)
              _buildReactionsRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsRow(BuildContext context) {
    final chatCtrl = Provider.of<ChatController>(context, listen: false);
    final entries = message.reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 44,
        right: isMe ? 44 : 0,
        top: 2,
        bottom: 2,
      ),
      child: Wrap(
        spacing: 4,
        children: entries.map((e) {
          final alreadyReacted = e.value.contains(currentUserId);
          return GestureDetector(
            onTap: () async {
              if (alreadyReacted) {
                await chatCtrl.removeReaction(
                    chatId, message.messageId, e.key);
              } else {
                await chatCtrl.addReaction(
                    chatId, message.messageId, e.key);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: alreadyReacted
                    ? AppTheme.lightPrimaryColor.withValues(alpha: 0.15)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: alreadyReacted
                    ? Border.all(
                        color: AppTheme.lightPrimaryColor, width: 1)
                    : null,
              ),
              child: Text(
                '${e.key} ${e.value.length}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final reply = message.replyTo!;
    final previewText = reply.type == 'image'
        ? '📷 Photo'
        : reply.type == 'voice'
            ? '🎤 Voice message'
            : reply.type == 'file'
                ? '📎 File'
                : reply.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : AppTheme.lightPrimaryColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : AppTheme.lightPrimaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            previewText,
            style: TextStyle(
              fontSize: 12,
              color: isMe
                  ? Colors.white70
                  : AppTheme.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.lightPrimaryColor,
      child: Text(
        message.senderName.isNotEmpty
            ? message.senderName[0].toUpperCase()
            : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDeleted) {
    if (isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    switch (message.type) {
      case AppConstants.textMessage:
        return _buildTextMessage();
      case AppConstants.imageMessage:
        return _buildImageMessage();
      case AppConstants.voiceMessage:
        return _buildVoiceMessage(context);
      case AppConstants.fileMessage:
        return _buildFileMessage(context);
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() => Text(
        message.content,
        style: TextStyle(
          fontSize: fontSize,
          color: isMe ? Colors.white : AppTheme.lightTextPrimary,
        ),
      );

  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty && message.content != 'Photo')
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : AppTheme.lightTextPrimary,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl ?? '',
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.error, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceMessage(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chatController, _) {
        final isPlaying =
            chatController.currentPlayingMessageId == message.messageId;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                if (message.mediaUrl != null) {
                  chatController.playVoiceMessage(
                      message.messageId, message.mediaUrl!);
                }
              },
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: isMe ? Colors.white : AppTheme.lightPrimaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _formatDuration(message.voiceDuration ?? 0),
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe
                          ? Colors.white
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageStatus() {
    final status = message.status;
    final tickColor =
        status == 'read' ? const Color(0xFF53BDEB) : Colors.white70;
    if (status == 'sent') {
      return const Icon(Icons.check, size: 14, color: Colors.white70);
    }
    return Stack(
      children: [
        Icon(Icons.check, size: 14, color: tickColor),
        Positioned(
            left: 4,
            child: Icon(Icons.check, size: 14, color: tickColor)),
      ],
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chatController, _) {
        return GestureDetector(
          onTap: () {
            if (message.mediaUrl != null && message.fileName != null) {
              chatController.downloadFile(
                  message.mediaUrl!, message.fileName!);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.white24 : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white30 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getFileIcon(message.fileExtension ?? ''),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.fileName ?? 'File',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isMe
                              ? Colors.white
                              : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        message.fileSize ?? '0 KB',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white70
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.download,
                    color: isMe
                        ? Colors.white70
                        : AppTheme.lightTextSecondary,
                    size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📋';
      case 'zip':
      case 'rar':
      case '7z':
        return '📦';
      case 'mp3':
      case 'wav':
        return '🎵';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '🎬';
      default:
        return '📎';
    }
  }
}
