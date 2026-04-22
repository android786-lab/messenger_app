# Firebase Database Structure

## Firestore Collections

### 1. Users Collection (`users`)
```
users/{userId}
├── uid: string
├── email: string
├── name: string
├── photoUrl: string (optional)
├── isOnline: boolean
├── lastSeen: timestamp
└── createdAt: timestamp
```

### 2. Chats Collection (`chats`)
```
chats/{chatId}
├── chatId: string
├── participants: array of user IDs
├── lastMessage: string
├── lastMessageType: string ('text', 'image', 'voice')
├── lastMessageTime: timestamp
├── lastMessageSenderId: string
├── unreadCount: map {userId: count}
├── isGroup: boolean
├── groupName: string (optional, for groups)
└── groupPhotoUrl: string (optional, for groups)
```

### 3. Messages Subcollection (`chats/{chatId}/messages`)
```
chats/{chatId}/messages/{messageId}
├── messageId: string
├── senderId: string
├── senderName: string
├── content: string
├── type: string ('text', 'image', 'voice')
├── timestamp: timestamp
├── isRead: boolean
├── mediaUrl: string (optional, for images/voice)
└── voiceDuration: number (optional, for voice messages)
```

## Firebase Storage Structure

### Storage Buckets
```
gs://your-project.appspot.com/
├── profile_pictures/
│   └── {timestamp}.jpg
├── chat_images/
│   └── {timestamp}.jpg
└── voice_messages/
    └── {timestamp}.m4a
```

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // Allow reading other users for search
    }
    
    // Chat access rules
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
    }
    
    // Message access rules
    match /chats/{chatId}/messages/{messageId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
    }
  }
}
```

### Storage Security Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_pictures/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    match /chat_images/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    match /voice_messages/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Real-time Data Flow

### 1. Chat List Updates
- Listen to `chats` collection where `participants` array contains current user ID
- Order by `lastMessageTime` descending
- Updates automatically when new messages arrive

### 2. Message Updates
- Listen to `chats/{chatId}/messages` subcollection
- Order by `timestamp` descending
- Real-time updates for new messages

### 3. User Status Updates
- Update `isOnline` and `lastSeen` fields in user document
- Listen to user documents for online status in chat list

## Indexing Requirements

### Composite Indexes
1. **Chat queries**: `participants` (array) + `lastMessageTime` (descending)
2. **Message queries**: `timestamp` (descending)
3. **User search**: `email` (ascending)

## Scalability Considerations

### 1. Message Pagination
- Implement pagination for message loading
- Load messages in batches (e.g., 50 messages at a time)
- Use `startAfter` for pagination

### 2. Chat List Optimization
- Limit chat list to recent chats
- Archive old chats to separate collection

### 3. Storage Optimization
- Compress images before upload
- Set maximum file sizes
- Implement automatic cleanup for old media files

### 4. Real-time Listeners
- Detach listeners when not needed
- Use appropriate query limits
- Implement connection state monitoring

# Firebase Database Schema

## Collections

### `users/{uid}`
```
uid: string
email: string
name: string
phone: string (digits only, normalized)
about: string?
photoUrl: string?
isOnline: bool
lastSeen: timestamp
createdAt: timestamp
lastSeenPrivacy: 'everyone' | 'contacts' | 'nobody'
profilePhotoPrivacy: 'everyone' | 'contacts' | 'nobody'
aboutPrivacy: 'everyone' | 'contacts' | 'nobody'
onlineStatusPrivacy: 'everyone' | 'contacts' | 'nobody'
```

### `users/{uid}/contacts/{contactId}`
```
id: string
name: string
phone: string
email: string?
photoUrl: string?
address: string?
company: string?
jobTitle: string?
notes: string?
nickname: string?
birthday: string? (ISO 8601)
createdAt: string (ISO 8601)
```

### `chats/{chatId}`
```
chatId: string
participants: string[]  (uids)
lastMessage: string
lastMessageType: 'text' | 'image' | 'voice' | 'file' | 'deleted'
lastMessageTime: timestamp
lastMessageSenderId: string
unreadCount: { [uid]: number }
isGroup: bool
groupName: string?
groupPhotoUrl: string?
groupDescription: string?
isPinned: bool
isArchived: bool
isFavorite: bool
isLocked: bool
pinnedTime: timestamp?
admins: string[]  (uids — group only)
mutedBy: string[]  (uids who muted this chat)
disappearingSeconds: number  (0 = off)
```

### `chats/{chatId}/messages/{messageId}`
```
messageId: string
senderId: string
senderName: string
content: string
type: 'text' | 'image' | 'voice' | 'file' | 'deleted'
timestamp: timestamp
isRead: bool
status: 'sent' | 'delivered' | 'read'
mediaUrl: string?
voiceDuration: number?  (seconds)
fileName: string?
fileSize: string?
fileExtension: string?
isPinned: bool
isStarred: bool
deletedFor: string[]  (uids — soft delete)
replyTo: {
  messageId: string
  senderName: string
  content: string
  type: string
}?
forwardedFrom: string?  (original sender name)
reactions: { [emoji]: string[] }  (emoji -> list of uids)
expiresAt: timestamp?  (disappearing messages)
```

### `chats/{chatId}/typing/{uid}`
```
isTyping: bool
updatedAt: serverTimestamp
```

### `blocked_users/{uid}`
```
blockedUsers: string[]  (uids)
```

## Firebase Storage Paths
```
profile_pictures/{uid}/{filename}
chat_images/{chatId}/{filename}
voice_messages/{chatId}/{filename}
chat_files/{chatId}/{filename}
```

## Firestore Indexes Required
- `chats`: `participants` (array-contains) + `lastMessageTime` (desc)
- `messages`: `timestamp` (desc)
- `messages`: `isStarred` (==) + `timestamp` (desc)
- `messages`: `status` (in) — for mark-as-read queries
