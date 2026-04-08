// App-wide constants
class AppConstants {
  // Collection names
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String groupsCollection = 'groups';

  // Storage paths
  static const String profilePicsPath = 'profile_pictures';
  static const String chatImagesPath = 'chat_images';
  static const String voiceMessagesPath = 'voice_messages';
  static const String filesPath = 'chat_files';

  // Message types
  static const String textMessage = 'text';
  static const String imageMessage = 'image';
  static const String voiceMessage = 'voice';
  static const String fileMessage = 'file';

  // Limits
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVoiceMessageDuration = 120; // 2 minutes
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  // Supported file types
  static const List<String> supportedFileTypes = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'rtf',
    'zip',
    'rar',
    '7z',
    'mp3',
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'mkv',
  ];
}
