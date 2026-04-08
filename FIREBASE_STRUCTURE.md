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