import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_formatter.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.chatBubbleMe : AppTheme.chatBubbleOther,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName.isNotEmpty)
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
                  _buildMessageContent(context),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TimeFormatter.formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white70
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      if (isMe) ...[
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

  Widget _buildMessageContent(BuildContext context) {
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

  Widget _buildTextMessage() {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 16,
        color: isMe ? Colors.white : AppTheme.lightTextPrimary,
      ),
    );
  }

  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty && message.content != 'Photo')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 16,
                color: isMe ? Colors.white : AppTheme.lightTextPrimary,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl ?? '',
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
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
      builder: (context, chatController, child) {
        bool isPlaying =
            chatController.currentPlayingMessageId == message.messageId;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                if (message.mediaUrl != null) {
                  chatController.playVoiceMessage(
                    message.messageId,
                    message.mediaUrl!,
                  );
                }
              },
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: isMe ? Colors.white : AppTheme.lightPrimaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    _formatDuration(message.voiceDuration ?? 0),
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.white : AppTheme.lightTextPrimary,
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
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageStatus() {
    // Get message status
    final status = message.status;

    // Determine tick color based on status
    final tickColor = status == 'read'
        ? const Color(0xFF53BDEB) // Light blue for read
        : Colors.white70;

    // Single tick for sent
    if (status == 'sent') {
      return Icon(Icons.check, size: 14, color: Colors.white70);
    }

    // Double ticks for delivered or read
    return Stack(
      children: [
        Icon(Icons.check, size: 14, color: tickColor),
        Positioned(
          left: 4,
          child: Icon(Icons.check, size: 14, color: tickColor),
        ),
      ],
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chatController, child) {
        return GestureDetector(
          onTap: () {
            if (message.mediaUrl != null && message.fileName != null) {
              chatController.downloadFile(message.mediaUrl!, message.fileName!);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.white24 : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // File icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white30 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getFileIcon(message.fileExtension ?? ''),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.fileName ?? 'File',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isMe
                              ? Colors.white
                              : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.fileSize ?? '0 KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe
                              ? Colors.white70
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Download icon
                Icon(
                  Icons.download,
                  color: isMe ? Colors.white70 : AppTheme.lightTextSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
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
      case 'txt':
      case 'rtf':
        return '📄';
      case 'zip':
      case 'rar':
      case '7z':
        return '📦';
      case 'mp3':
      case 'wav':
      case 'flac':
        return '🎵';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'mkv':
        return '🎬';
      default:
        return '📎';
    }
  }
}
