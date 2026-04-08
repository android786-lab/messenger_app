/-# Facebook Messenger Clone - Project Documentation

> **Purpose:** This document explains the complete design, architecture, and implementation of the Facebook Messenger Clone app. It is written for a university viva presentation and covers every major aspect of the project in plain, clear English.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Project Structure](#3-project-structure)
4. [Frontend Explanation](#4-frontend-explanation)
5. [Backend Explanation](#5-backend-explanation)
6. [API / Firebase Details](#6-api--firebase-details)
7. [Database (Firestore)](#7-database-firestore)
8. [Authentication & Security](#8-authentication--security)
9. [Features Explanation](#9-features-explanation)
10. [Data Flow](#10-data-flow)
11. [Important Functions](#11-important-functions)
12. [Common Viva Questions & Answers](#12-common-viva-questions--answers)

---

## 1. Project Overview

The **Facebook Messenger Clone** is a fully functional real-time chat application built using Flutter and Firebase. It replicates the core features of a modern messaging app, including one-on-one chats, group chats, voice messages, file sharing, contact management, and security features like biometric app lock.

### What the app does

- Users can register and log in using their email and password.
- They can search for other users and start a conversation.
- Messages can be text, images, voice recordings, or files.
- Users can create group chats and manage members.
- The app shows online/offline status and message read receipts.
- Contacts can be saved locally (like a phonebook) and the app checks which contacts are already using the app.
- Non-app contacts can be invited via SMS.
- Chats can be pinned, archived, favorited, or locked.
- Users can block others and enable biometric app lock for privacy.
- Dark mode is supported and remembered across sessions.

### Who it is for

This app is designed as a learning and demonstration project that shows how to build a production-quality Flutter app with a real Firebase backend. It covers authentication, real-time data, file storage, state management, and device features.

---

## 2. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Flutter (Dart) | Cross-platform mobile UI |
| State Management | Provider | Manage and share app state |
| Backend | Firebase | Cloud services (auth, database, storage) |
| Authentication | Firebase Auth | Email/password login and registration |
| Database | Cloud Firestore | Real-time NoSQL database |
| File Storage | Firebase Storage | Store images, voice, and files |
| Local Storage | SharedPreferences | Save theme and app lock settings |
| Biometrics | local_auth | Fingerprint / face unlock |
| Voice | flutter_sound + audioplayers | Record and play voice messages |
| Images | image_picker + cached_network_image | Pick and display images |
| Files | file_picker | Pick any file type |
| SMS Invite | url_launcher | Open SMS app with pre-filled message |

### Why Flutter?

Flutter allows writing one codebase that runs on both Android and iOS. It uses the Dart language and provides a rich set of widgets for building beautiful UIs. It is fast because it compiles to native ARM code.

### Why Firebase?

Firebase is a Backend-as-a-Service (BaaS) platform by Google. It removes the need to build and maintain a custom server. Firestore provides real-time data sync, which is essential for a chat app. Firebase Auth handles secure login without writing authentication logic from scratch.

### Why Provider?

Provider is the recommended state management solution for Flutter. It allows controllers (like `AuthController`, `ChatController`) to hold state and notify the UI when data changes. It is simple, efficient, and well-documented.

---

## 3. Project Structure

```
facebook_messanger/
├── android/                    # Android-specific native code and config
│   └── app/
│       ├── google-services.json    # Firebase config for Android
│       └── src/main/
│           └── AndroidManifest.xml # App permissions (camera, mic, etc.)
├── ios/                        # iOS-specific native code and config
├── assets/
│   ├── icons/                  # App icon assets
│   └── images/                 # Static image assets
├── lib/                        # All Dart source code lives here
│   ├── main.dart               # App entry point, Firebase init, Provider setup
│   ├── firebase_options.dart   # Auto-generated Firebase config
│   ├── models/                 # Data model classes
│   │   ├── user_model.dart
│   │   ├── chat_model.dart
│   │   ├── message_model.dart
│   │   └── local_contact.dart
│   ├── services/               # Direct Firebase/device API calls
│   │   ├── auth_service.dart
│   │   ├── chat_service.dart
│   │   ├── storage_service.dart
│   │   ├── block_service.dart
│   │   └── app_lock_service.dart
│   ├── controllers/            # Business logic, uses services, notifies UI
│   │   ├── auth_controller.dart
│   │   ├── chat_controller.dart
│   │   ├── contacts_controller.dart
│   │   ├── theme_controller.dart
│   │   ├── block_controller.dart
│   │   └── app_lock_controller.dart
│   └── screens/                # UI screens
│       ├── auth/
│       │   ├── login_screen.dart
│       │   ├── signup_screen.dart
│       │   └── app_lock_screen.dart
│       ├── chat/
│       │   ├── chat_list_screen.dart
│       │   ├── chat_screen.dart
│       │   └── new_chat_screen.dart
│       ├── contacts/
│       │   ├── contacts_screen.dart
│       │   └── add_contact_screen.dart
│       ├── group/
│       │   └── create_group_screen.dart
│       └── profile/
│           └── profile_screen.dart
├── pubspec.yaml                # Dependencies and assets declaration
└── PROJECT_DOCUMENTATION.md   # This file
```

### Folder Responsibilities

| Folder | What it contains |
|---|---|
| `models/` | Plain Dart classes that represent data (like database row objects) |
| `services/` | Code that talks directly to Firebase or device APIs |
| `controllers/` | Business logic that connects services to the UI using Provider |
| `screens/` | Flutter widgets that the user sees and interacts with |

This separation follows the **MVC-like pattern** (Model-View-Controller), which keeps the code organized and easy to maintain.

---

## 4. Frontend Explanation

The frontend is built entirely with Flutter widgets. Each screen is a `StatefulWidget` or `StatelessWidget` that listens to controllers via `Provider` and rebuilds when data changes.

### Screen-by-Screen Breakdown

---

### 4.1 Login Screen (`lib/screens/auth/login_screen.dart`)

**Purpose:** Allows existing users to sign in.

**UI Elements:**
- Email text field
- Password text field (with show/hide toggle)
- Login button
- Link to Sign Up screen

**How it works:**
1. User enters email and password.
2. On pressing Login, it calls `AuthController.signIn(email, password)`.
3. If successful, the user is navigated to `ChatListScreen`.
4. If it fails (wrong password, no account), an error message is shown using a `SnackBar`.

---

### 4.2 Sign Up Screen (`lib/screens/auth/signup_screen.dart`)

**Purpose:** Allows new users to create an account.

**UI Elements:**
- Name, email, phone, and password fields
- Register button

**How it works:**
1. User fills in all fields and presses Register.
2. Calls `AuthController.signUp(name, email, phone, password)`.
3. Firebase creates the user account and saves their profile to Firestore.
4. User is navigated to `ChatListScreen`.

---

### 4.3 App Lock Screen (`lib/screens/auth/app_lock_screen.dart`)

**Purpose:** Shown when the app is reopened and app lock is enabled.

**How it works:**
1. On app resume, `AppLockController.needsReauthentication()` is checked.
2. If true, this screen is shown.
3. The user must authenticate using fingerprint or face ID.
4. On success, the app continues to `ChatListScreen`.

---

### 4.4 Chat List Screen (`lib/screens/chat/chat_list_screen.dart`)

**Purpose:** The main home screen of the app. Shows all conversations.

**UI Elements:**
- Tab bar with "Chats" and "Contacts" tabs
- List of chat tiles (profile photo, name, last message, time, unread count)
- Floating action button to start a new chat
- App bar with search and settings icons

**How it works:**
- Uses `ChatController.listenToUserChats()` which returns a real-time Firestore stream.
- Each chat tile shows the other person's name, last message preview, timestamp, and unread badge.
- Pinned chats appear at the top.
- Archived chats are hidden unless the user taps "Archived".
- Long-pressing a chat shows options: pin, archive, delete, lock, favorite.

---

### 4.5 Chat Screen (`lib/screens/chat/chat_screen.dart`)

**Purpose:** The actual conversation screen where messages are sent and received.

**UI Elements:**
- Message list (scrollable, newest at bottom)
- Text input field
- Attachment button (image, voice, file)
- Send button
- App bar showing contact name, photo, and online status

**How it works:**
- Listens to `ChatController.listenToChatMessages(chatId)` for real-time messages.
- Each message bubble shows content, timestamp, and read status icon (sent ✓, delivered ✓✓, read ✓✓ in blue).
- When the screen opens, `markMessagesAsRead()` is called to clear unread count.
- Voice messages show a play button and duration.
- Image messages show a thumbnail that can be tapped to view full size.
- File messages show the file name, size, and extension with a download icon.

---

### 4.6 New Chat Screen (`lib/screens/chat/new_chat_screen.dart`)

**Purpose:** Start a new conversation. Styled like WhatsApp's new chat screen.

**UI Elements:**
- Search bar to find users by email
- "Contacts on App" section — contacts who are already using the app
- "Invite to App" section — contacts who are not on the app yet

**How it works:**
- `ContactsController.getContactsWithAppStatus()` cross-references saved contacts with Firestore users by phone number.
- Contacts found in Firestore are shown in the "on app" section with a "Message" button.
- Contacts not found are shown in the "invite" section with an "Invite" button.
- Tapping "Invite" opens the SMS app with a pre-filled invitation message using `url_launcher`.
- Tapping a contact calls `ChatController.getOrCreateChat()` and opens `ChatScreen`.

---

### 4.7 Contacts Screen (`lib/screens/contacts/contacts_screen.dart`)

**Purpose:** Shows the user's saved phonebook contacts.

**UI Elements:**
- Alphabetically sorted list of contacts
- Each contact shows name, phone, and profile photo (if available)
- Floating action button to add a new contact

**How it works:**
- Contacts are stored in Firestore under `users/{uid}/contacts/`.
- `ContactsController.loadContacts()` fetches them on screen load.
- Tapping a contact shows their details and options to edit, delete, or message them.

---

### 4.8 Add Contact Screen (`lib/screens/contacts/add_contact_screen.dart`)

**Purpose:** Save a new contact to the user's phonebook.

**UI Elements:**
- Name and phone number fields
- Save button

**How it works:**
- Calls `ContactsController.addContact(name, phone)`.
- Saves the contact to Firestore under `users/{uid}/contacts/{id}`.
- The contact list screen refreshes automatically.

---

### 4.9 Create Group Screen (`lib/screens/group/create_group_screen.dart`)

**Purpose:** Create a new group chat.

**UI Elements:**
- Group name field
- Group photo picker
- List of contacts to select as members
- Create button

**How it works:**
- User selects members from their contacts list.
- Calls `ChatController.createGroupChat(groupName, memberIds, groupPhotoUrl)`.
- A new chat document is created in Firestore with `isGroup: true`.
- All members are added to the `participants` list.

---

### 4.10 Profile Screen (`lib/screens/profile/profile_screen.dart`)

**Purpose:** View and edit the current user's profile.

**UI Elements:**
- Profile photo (tappable to change)
- Name, email, phone fields
- Save button
- Logout button
- App lock toggle
- Dark mode toggle

**How it works:**
- Loads current user data from `AuthController.streamCurrentUser()`.
- Photo change calls `StorageService.uploadProfilePicture()` then updates Firestore.
- Calls `AuthController.updateProfile()` to save name/phone changes.
- App lock toggle calls `AppLockController.toggleAppLock()`.
- Theme toggle calls `ThemeController.toggleTheme()`.

---

### UI Flow Diagram

```
App Start
    │
    ├── App Lock Enabled? ──Yes──► AppLockScreen (biometric)
    │                                    │
    │                                    ▼
    ├── User Logged In? ──No──► LoginScreen ──► SignUpScreen
    │                                    │
    │                                    ▼
    └──────────────────────────► ChatListScreen (Home)
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
              ChatScreen         NewChatScreen        ContactsScreen
                                        │                   │
                                 CreateGroupScreen    AddContactScreen
                                        │
                                  ProfileScreen
```

---

## 5. Backend Explanation

The backend of this app is entirely powered by **Firebase**, which is Google's cloud platform for mobile and web apps. There is no custom server — Firebase handles everything.

### Firebase Services Used

| Service | What it does in this app |
|---|---|
| Firebase Auth | Manages user accounts, login, and logout |
| Cloud Firestore | Stores all user data, chats, and messages in real time |
| Firebase Storage | Stores uploaded images, voice recordings, and files |

### How Firebase is Initialized

In `lib/main.dart`, Firebase is initialized before the app starts:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

The `DefaultFirebaseOptions` class is auto-generated in `lib/firebase_options.dart` by the FlutterFire CLI. It contains the API keys and project IDs for both Android and iOS.

### How Provider is Set Up

All controllers are registered as `ChangeNotifierProvider` at the top of the widget tree in `main.dart`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthController()),
    ChangeNotifierProvider(create: (_) => ChatController()),
    ChangeNotifierProvider(create: (_) => ContactsController()),
    ChangeNotifierProvider(create: (_) => ThemeController()),
    ChangeNotifierProvider(create: (_) => BlockController()),
    ChangeNotifierProvider(create: (_) => AppLockController()),
  ],
  child: MyApp(),
)
```

Any screen can then access a controller using:
```dart
final chatController = Provider.of<ChatController>(context);
// or
final chatController = context.read<ChatController>();
```

### How Real-Time Data Works

Firestore uses **streams** to push data to the app whenever something changes in the database. Instead of the app asking "any new messages?" every few seconds (polling), Firestore sends updates automatically (push).

```dart
// Example: listening to messages in real time
Stream<List<MessageModel>> getChatMessages(String chatId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList());
}
```

The UI uses a `StreamBuilder` widget to listen to this stream and rebuild whenever new messages arrive.

### Architecture Overview

```
UI (Screens)
    │  calls methods / reads state
    ▼
Controllers (Provider ChangeNotifiers)
    │  calls service methods
    ▼
Services (Firebase wrappers)
    │  reads/writes
    ▼
Firebase (Auth / Firestore / Storage)
```

This layered architecture means:
- Screens never talk to Firebase directly.
- Services only handle Firebase calls, no business logic.
- Controllers contain the logic and notify the UI of changes.

---

## 6. API / Firebase Details

### 6.1 Firebase Authentication API

Firebase Auth is used for all user identity management.

| Operation | Firebase Method |
|---|---|
| Register | `FirebaseAuth.instance.createUserWithEmailAndPassword()` |
| Login | `FirebaseAuth.instance.signInWithEmailAndPassword()` |
| Logout | `FirebaseAuth.instance.signOut()` |
| Get current user | `FirebaseAuth.instance.currentUser` |
| Listen to auth state | `FirebaseAuth.instance.authStateChanges()` |

**Example — Sign Up:**
```dart
UserCredential credential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
String uid = credential.user!.uid;
```

After creating the account, the user's profile data (name, phone, etc.) is saved to Firestore manually because Firebase Auth only stores email and password.

### 6.2 Cloud Firestore API

Firestore is a NoSQL document database. Data is organized in **collections** (like folders) and **documents** (like files).

| Operation | Firestore Method |
|---|---|
| Create/overwrite document | `doc.set(data)` |
| Update specific fields | `doc.update(fields)` |
| Read once | `doc.get()` |
| Real-time stream | `doc.snapshots()` or `collection.snapshots()` |
| Query with filter | `collection.where('field', isEqualTo: value)` |
| Delete document | `doc.delete()` |
| Add to subcollection | `collection.add(data)` |

**Example — Send a message:**
```dart
await FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .add(message.toMap());
```

**Example — Query users by phone:**
```dart
QuerySnapshot result = await FirebaseFirestore.instance
    .collection('users')
    .where('phone', isEqualTo: phoneNumber)
    .get();
```

### 6.3 Firebase Storage API

Firebase Storage stores binary files (images, audio, documents).

| Operation | Firebase Storage Method |
|---|---|
| Upload file | `ref.putFile(file)` |
| Upload bytes | `ref.putData(bytes)` |
| Get download URL | `ref.getDownloadURL()` |
| Delete file | `ref.delete()` |

**Example — Upload a chat image:**
```dart
final ref = FirebaseStorage.instance
    .ref()
    .child('chat_images/$chatId/${uuid.v4()}.jpg');

await ref.putFile(imageFile);
String downloadUrl = await ref.getDownloadURL();
```

The download URL is then saved in the message document in Firestore so any user can load the image.

### 6.4 How the App Calls These APIs

The app never calls Firebase APIs directly from the UI. The call chain is:

```
Screen → Controller method → Service method → Firebase API
```

For example, sending a text message:
1. User taps Send in `ChatScreen`
2. `ChatScreen` calls `chatController.sendTextMessage(chatId, content)`
3. `ChatController` calls `chatService.sendMessage(chatId, message)`
4. `ChatService` calls `FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add(...)`

---

## 7. Database (Firestore)

Firestore is a cloud-hosted NoSQL database. Data is stored as JSON-like documents inside collections. This app uses the following collections:

### 7.1 Collection: `users`

**Path:** `users/{uid}`

Stores one document per registered user.

| Field | Type | Description |
|---|---|---|
| `uid` | String | Firebase Auth user ID (same as document ID) |
| `email` | String | User's email address |
| `name` | String | Display name |
| `photoUrl` | String | URL of profile picture in Firebase Storage |
| `phone` | String | Phone number (used for contact matching) |
| `isOnline` | Boolean | Whether the user is currently active |
| `lastSeen` | Timestamp | Last time the user was online |
| `createdAt` | Timestamp | Account creation time |

**Example document:**
```json
{
  "uid": "abc123",
  "email": "ali@example.com",
  "name": "Fida Hussain",
  "photoUrl": "https://firebasestorage.../photo.jpg",
  "phone": "+923001234567",
  "isOnline": true,
  "lastSeen": "2024-01-15T10:30:00Z",
  "createdAt": "2024-01-01T08:00:00Z"
}
```

---

### 7.2 Subcollection: `users/{uid}/contacts`

**Path:** `users/{uid}/contacts/{contactId}`

Each user has their own private phonebook stored as a subcollection.

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique contact ID (UUID) |
| `name` | String | Contact's display name |
| `phone` | String | Contact's phone number |
| `email` | String | Contact's email (optional) |
| `photoUrl` | String | Contact photo URL (optional) |
| `address` | String | Address (optional) |
| `company` | String | Company name (optional) |
| `jobTitle` | String | Job title (optional) |
| `notes` | String | Personal notes (optional) |
| `nickname` | String | Nickname (optional) |
| `birthday` | String | Birthday (optional) |
| `createdAt` | Timestamp | When contact was saved |

---

### 7.3 Collection: `chats`

**Path:** `chats/{chatId}`

One document per conversation (both 1-on-1 and group).

For 1-on-1 chats, the `chatId` is generated by sorting the two user UIDs alphabetically and joining them with an underscore:
```dart
String chatId = [uid1, uid2]..sort();
chatId = chatId.join('_');
```
This ensures the same two users always get the same chat document.

| Field | Type | Description |
|---|---|---|
| `chatId` | String | Unique chat identifier |
| `participants` | List\<String\> | UIDs of all members |
| `lastMessage` | String | Preview of the last message |
| `lastMessageType` | String | Type: text, image, voice, file |
| `lastMessageTime` | Timestamp | When the last message was sent |
| `lastMessageSenderId` | String | UID of who sent the last message |
| `unreadCount` | Map\<String, int\> | Unread count per user, e.g. `{"uid1": 3}` |
| `isGroup` | Boolean | True if this is a group chat |
| `groupName` | String | Group name (only for groups) |
| `groupPhotoUrl` | String | Group photo URL (only for groups) |
| `isPinned` | Boolean | Whether the chat is pinned to top |
| `isArchived` | Boolean | Whether the chat is archived |
| `isFavorite` | Boolean | Whether the chat is marked as favorite |
| `isLocked` | Boolean | Whether the chat requires extra auth to open |
| `pinnedTime` | Timestamp | When the chat was pinned (for sort order) |

**Example document:**
```json
{
  "chatId": "abc123_xyz789",
  "participants": ["abc123", "xyz789"],
  "lastMessage": "Hey, how are you?",
  "lastMessageType": "text",
  "lastMessageTime": "2024-01-15T10:35:00Z",
  "lastMessageSenderId": "abc123",
  "unreadCount": { "xyz789": 2 },
  "isGroup": false,
  "isPinned": false,
  "isArchived": false,
  "isFavorite": true,
  "isLocked": false
}
```

---

### 7.4 Subcollection: `chats/{chatId}/messages`

**Path:** `chats/{chatId}/messages/{messageId}`

Each message is stored as a document in the messages subcollection.

| Field | Type | Description |
|---|---|---|
| `messageId` | String | Unique message ID (UUID) |
| `senderId` | String | UID of the sender |
| `senderName` | String | Display name of sender (for groups) |
| `content` | String | Text content of the message |
| `type` | String | Message type: text, image, voice, file |
| `timestamp` | Timestamp | When the message was sent |
| `isRead` | Boolean | Whether the recipient has read it |
| `status` | String | Delivery status: sent, delivered, read |
| `mediaUrl` | String | Download URL for image/voice/file |
| `voiceDuration` | int | Duration of voice message in seconds |
| `fileName` | String | Original file name (for file messages) |
| `fileSize` | int | File size in bytes |
| `fileExtension` | String | File extension, e.g. "pdf", "docx" |

**Example text message:**
```json
{
  "messageId": "msg_001",
  "senderId": "abc123",
  "senderName": "Ali Hassan",
  "content": "Hey, how are you?",
  "type": "text",
  "timestamp": "2024-01-15T10:35:00Z",
  "isRead": false,
  "status": "delivered"
}
```

**Example voice message:**
```json
{
  "messageId": "msg_002",
  "senderId": "abc123",
  "type": "voice",
  "content": "Voice message",
  "mediaUrl": "https://firebasestorage.../voice_001.aac",
  "voiceDuration": 12,
  "timestamp": "2024-01-15T10:36:00Z",
  "status": "sent"
}
```

---

### 7.5 Collection: `blocked_users`

**Path:** `blocked_users/{uid}`

Stores the list of users that a given user has blocked.

| Field | Type | Description |
|---|---|---|
| `blockedUsers` | List\<String\> | List of UIDs that this user has blocked |

---

### 7.6 How Data Flows in the Database

**Sending a message (data flow):**
1. New message document is added to `chats/{chatId}/messages/`.
2. The parent `chats/{chatId}` document is updated with `lastMessage`, `lastMessageTime`, and incremented `unreadCount` for the recipient.
3. The recipient's `StreamBuilder` detects the change and rebuilds the UI.

**Reading messages:**
1. `ChatService.getChatMessages(chatId)` returns a Firestore stream.
2. The stream emits a new list every time a message is added or updated.
3. `ChatScreen` uses `StreamBuilder` to display the latest list.

**Marking messages as read:**
1. When `ChatScreen` opens, `markMessagesAsRead(chatId, userId)` is called.
2. This queries all messages where `isRead == false` and `senderId != currentUserId`.
3. It updates each message's `isRead` to `true` and `status` to `"read"`.
4. It also resets `unreadCount[currentUserId]` to `0` in the chat document.

---

## 8. Authentication & Security

### 8.1 How User Registration Works

1. User fills in name, email, phone, and password on `SignUpScreen`.
2. `AuthController.signUp()` is called.
3. `AuthService.signUp()` calls Firebase Auth's `createUserWithEmailAndPassword()`.
4. Firebase creates the account and returns a `UserCredential` with a unique `uid`.
5. A new document is created in `users/{uid}` with the user's profile data.
6. The user is automatically logged in and navigated to `ChatListScreen`.

**Code snippet:**
```dart
Future<void> signUp(String name, String email, String phone, String password) async {
  UserCredential credential = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(email: email, password: password);
  
  String uid = credential.user!.uid;
  
  UserModel user = UserModel(
    uid: uid,
    email: email,
    name: name,
    phone: phone,
    photoUrl: '',
    isOnline: true,
    lastSeen: DateTime.now(),
    createdAt: DateTime.now(),
  );
  
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set(user.toMap());
}
```

### 8.2 How User Login Works

1. User enters email and password on `LoginScreen`.
2. `AuthController.signIn()` is called.
3. `AuthService.signIn()` calls Firebase Auth's `signInWithEmailAndPassword()`.
4. If credentials are correct, Firebase returns the user's `uid`.
5. The user's `isOnline` status is set to `true` in Firestore.
6. The user is navigated to `ChatListScreen`.

**Error handling:**
- If the email is not registered, Firebase throws `user-not-found`.
- If the password is wrong, Firebase throws `wrong-password`.
- These errors are caught and shown to the user in a `SnackBar`.

### 8.3 How Logout Works

1. User taps Logout in `ProfileScreen`.
2. `AuthController.signOut()` is called.
3. The user's `isOnline` status is set to `false` and `lastSeen` is updated.
4. `FirebaseAuth.instance.signOut()` is called.
5. The user is navigated back to `LoginScreen`.

### 8.4 Session Management

Firebase Auth automatically manages sessions. Once logged in, the user stays logged in even if the app is closed. The session is stored securely on the device.

To check if a user is logged in:
```dart
User? currentUser = FirebaseAuth.instance.currentUser;
if (currentUser != null) {
  // User is logged in
}
```

The app uses `authStateChanges()` stream to listen for login/logout events:
```dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    // Navigate to LoginScreen
  } else {
    // Navigate to ChatListScreen
  }
});
```

### 8.5 Online/Offline Status

When a user logs in, their `isOnline` field is set to `true`. When they log out or close the app, it is set to `false` and `lastSeen` is updated.

**Implementation:**
- `AuthController.updateOnlineStatus(bool isOnline)` updates Firestore.
- This is called in `initState()` of `ChatListScreen` (set to `true`) and in `dispose()` or logout (set to `false`).

**Limitation:** If the app crashes or is force-closed, the status may not update immediately. A production app would use Firebase's `onDisconnect()` feature to handle this automatically.

### 8.6 Blocking Users

Users can block others to prevent them from sending messages.

**How it works:**
1. User long-presses a chat and selects "Block".
2. `BlockController.blockUser(blockedUserId)` is called.
3. The blocked user's UID is added to `blocked_users/{currentUserId}`.
4. The chat is hidden from the chat list.
5. If the blocked user tries to send a message, the app checks `BlockService.isUserBlocked()` and prevents it.

**Unblocking:**
- User goes to Settings → Blocked Users.
- Taps "Unblock" next to a user.
- The UID is removed from the `blockedUsers` list.

### 8.7 App Lock (Biometric Authentication)

Users can enable app lock to require fingerprint or face ID when opening the app.

**How it works:**
1. User toggles "App Lock" in `ProfileScreen`.
2. `AppLockController.toggleAppLock()` saves the setting to `SharedPreferences`.
3. When the app is resumed from the background, `AppLockController.needsReauthentication()` checks if more than 30 seconds have passed.
4. If yes, `AppLockScreen` is shown.
5. `AppLockService.authenticate()` calls `local_auth` package to prompt biometric authentication.
6. On success, the user proceeds to the app.

**Code snippet:**
```dart
Future<bool> authenticate() async {
  final LocalAuthentication auth = LocalAuthentication();
  
  bool canCheckBiometrics = await auth.canCheckBiometrics;
  if (!canCheckBiometrics) return false;
  
  return await auth.authenticate(
    localizedReason: 'Authenticate to unlock the app',
    options: const AuthenticationOptions(biometricOnly: true),
  );
}
```

### 8.8 Data Privacy

- User passwords are never stored in Firestore. Firebase Auth handles them securely.
- Profile photos and media files are stored in Firebase Storage with access rules.
- Firestore security rules (not included in this project) should be configured to ensure users can only read/write their own data.

**Example Firestore security rule:**
```javascript
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;
}
```

---

## 9. Features Explanation

This section explains each major feature in detail.

---

### 9.1 Real-Time Messaging

**What it does:** Messages appear instantly without refreshing.

**How it works:**
- Firestore's `snapshots()` method returns a stream that emits new data whenever the database changes.
- The UI uses `StreamBuilder` to listen to this stream.
- When a new message is added, the stream emits the updated list and the UI rebuilds automatically.

**Code example:**
```dart
StreamBuilder<List<MessageModel>>(
  stream: chatController.listenToChatMessages(chatId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    List<MessageModel> messages = snapshot.data!;
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) => MessageBubble(messages[index]),
    );
  },
)
```

---

### 9.2 Image Messages

**What it does:** Users can send photos from their gallery or camera.

**How it works:**
1. User taps the attachment icon and selects "Image".
2. `image_picker` package opens the gallery or camera.
3. User selects an image.
4. `StorageService.uploadChatImage(chatId, imageFile)` uploads the image to Firebase Storage.
5. Firebase returns a download URL.
6. A new message document is created with `type: "image"` and `mediaUrl: downloadUrl`.
7. The recipient's `ChatScreen` displays the image using `CachedNetworkImage`.

**Code snippet:**
```dart
Future<void> sendImageMessage(String chatId, File imageFile) async {
  String imageUrl = await storageService.uploadChatImage(chatId, imageFile);
  
  MessageModel message = MessageModel(
    messageId: Uuid().v4(),
    senderId: currentUserId,
    type: 'image',
    content: 'Image',
    mediaUrl: imageUrl,
    timestamp: DateTime.now(),
    status: 'sent',
  );
  
  await chatService.sendMessage(chatId, message);
}
```

---

### 9.3 Voice Messages

**What it does:** Users can record and send voice messages.

**How it works:**
1. User long-presses the microphone icon.
2. `flutter_sound` package starts recording audio.
3. User releases the button to stop recording.
4. The audio file is saved locally.
5. `StorageService.uploadVoiceMessage(chatId, audioFile)` uploads it to Firebase Storage.
6. A message with `type: "voice"`, `mediaUrl`, and `voiceDuration` is created.
7. The recipient sees a play button and duration.
8. Tapping play uses `audioplayers` package to play the audio.

**Permissions required:**
- Microphone permission (declared in `AndroidManifest.xml` and `Info.plist`).

---

### 9.4 File Sharing

**What it does:** Users can send any file type (PDF, DOCX, ZIP, etc.).

**How it works:**
1. User taps attachment icon and selects "File".
2. `file_picker` package opens the file browser.
3. User selects a file.
4. `StorageService.uploadFile(chatId, file)` uploads it to Firebase Storage.
5. A message with `type: "file"`, `fileName`, `fileSize`, `fileExtension`, and `mediaUrl` is created.
6. The recipient sees the file name and a download icon.
7. Tapping the icon opens the file URL in the browser or downloads it.

---

### 9.5 Group Chats

**What it does:** Multiple users can chat in one conversation.

**How it works:**
1. User taps "New Group" in `ChatListScreen`.
2. `CreateGroupScreen` opens.
3. User enters a group name, selects members, and optionally uploads a group photo.
4. `ChatController.createGroupChat(groupName, memberIds, groupPhotoUrl)` is called.
5. A new chat document is created with `isGroup: true` and `participants: [uid1, uid2, uid3, ...]`.
6. All members see the group in their chat list.
7. Messages in the group show the sender's name.

**Adding/removing members:**
- `ChatController.addMemberToGroup(chatId, userId)` adds a UID to the `participants` list.
- `ChatController.removeMemberFromGroup(chatId, userId)` removes a UID.

---

### 9.6 Contact System

**What it does:** Users can save contacts (like a phonebook) and see which contacts are on the app.

**How it works:**
1. User adds a contact with name and phone in `AddContactScreen`.
2. The contact is saved to `users/{uid}/contacts/{id}`.
3. In `NewChatScreen`, `ContactsController.getContactsWithAppStatus()` is called.
4. This method queries Firestore's `users` collection for each contact's phone number.
5. If a match is found, the contact is marked as "on app".
6. If not, the contact is marked as "invite to app".

**Code snippet:**
```dart
Future<Map<String, List<LocalContact>>> getContactsWithAppStatus() async {
  List<LocalContact> allContacts = await loadContacts();
  List<LocalContact> onApp = [];
  List<LocalContact> notOnApp = [];
  
  for (var contact in allContacts) {
    QuerySnapshot result = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: contact.phone)
        .get();
    
    if (result.docs.isNotEmpty) {
      onApp.add(contact);
    } else {
      notOnApp.add(contact);
    }
  }
  
  return {'onApp': onApp, 'notOnApp': notOnApp};
}
```

---

### 9.7 Invite Non-App Contacts

**What it does:** Users can invite contacts who are not on the app via SMS.

**How it works:**
1. In `NewChatScreen`, contacts not on the app have an "Invite" button.
2. Tapping it calls `url_launcher` with an SMS URI:
   ```dart
   final Uri smsUri = Uri(
     scheme: 'sms',
     path: contact.phone,
     queryParameters: {'body': 'Hey! Join me on Facebook Messenger Clone: [app link]'},
   );
   await launchUrl(smsUri);
   ```
3. The device's SMS app opens with the message pre-filled.
4. The user can edit and send the SMS.

---

### 9.8 Message Read Receipts

**What it does:** Shows if a message was sent, delivered, or read.

**How it works:**
- When a message is sent, its `status` is set to `"sent"`.
- When the recipient's app receives the message (via the stream), the status is updated to `"delivered"`.
- When the recipient opens the chat, `markMessagesAsRead()` is called, which updates `status` to `"read"` and sets `isRead: true`.

**UI indicators:**
- Sent: Single gray checkmark ✓
- Delivered: Double gray checkmarks ✓✓
- Read: Double blue checkmarks ✓✓ (blue)

---

### 9.9 Unread Message Count

**What it does:** Shows a badge with the number of unread messages in each chat.

**How it works:**
- The `chats/{chatId}` document has an `unreadCount` map: `{"uid1": 3, "uid2": 0}`.
- When a message is sent, the recipient's count is incremented.
- When the recipient opens the chat, `markMessagesAsRead()` resets their count to `0`.
- The chat list screen displays the count as a badge.

---

### 9.10 Pin, Archive, Favorite, Lock Chats

**What it does:** Organize chats for easier access.

**How it works:**
- Each chat document has boolean fields: `isPinned`, `isArchived`, `isFavorite`, `isLocked`.
- Long-pressing a chat shows options to toggle these.
- `ChatController.updateChatPinStatus(chatId, isPinned)` updates the field in Firestore.
- Pinned chats are sorted to the top of the list.
- Archived chats are hidden unless the user taps "Archived".
- Locked chats require biometric authentication to open.

---

### 9.11 Dark Mode

**What it does:** Switches the app's theme between light and dark.

**How it works:**
1. `ThemeController` manages the theme state.
2. The current theme is saved to `SharedPreferences`.
3. On app start, the saved theme is loaded.
4. The `MaterialApp` widget uses `ThemeController.isDarkMode` to set the theme:
   ```dart
   MaterialApp(
     theme: ThemeData.light(),
     darkTheme: ThemeData.dark(),
     themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
   )
   ```
5. Toggling the theme calls `ThemeController.toggleTheme()`, which updates the state and saves to `SharedPreferences`.

---

## 10. Data Flow

This section shows end-to-end examples of how data moves through the app.

---

### 10.1 End-to-End: Sending a Text Message

```
User types "Hello" and taps Send
        │
        ▼
ChatScreen.sendMessage()
        │
        ▼
ChatController.sendTextMessage(chatId, "Hello")
        │  Creates MessageModel object
        ▼
ChatService.sendMessage(chatId, messageModel)
        │
        ├──► Firestore: Add document to chats/{chatId}/messages/
        │    {messageId, senderId, content: "Hello", type: "text", status: "sent", ...}
        │
        └──► Firestore: Update chats/{chatId}
             {lastMessage: "Hello", lastMessageTime: now, unreadCount: {recipientId: +1}}
        │
        ▼
Recipient's ChatScreen StreamBuilder detects change
        │
        ▼
UI rebuilds and shows "Hello" message bubble
        │
        ▼
Recipient opens chat → markMessagesAsRead() called
        │
        ▼
Firestore: Update message status to "read", unreadCount reset to 0
        │
        ▼
Sender's ChatScreen detects status change → shows blue checkmarks
```

---

### 10.2 End-to-End: Sending a Voice Message

```
User holds microphone button
        │
        ▼
flutter_sound starts recording audio
        │
User releases button
        │
        ▼
flutter_sound stops recording, saves .aac file locally
        │
        ▼
ChatController.sendVoiceMessage(chatId, audioFile, duration)
        │
        ▼
StorageService.uploadVoiceMessage(chatId, audioFile)
        │  Uploads to Firebase Storage
        ▼
Firebase Storage returns download URL
        │
        ▼
ChatService.sendMessage(chatId, {type: "voice", mediaUrl: url, voiceDuration: 12})
        │
        ▼
Recipient sees voice message bubble with play button and "0:12" duration
        │
        ▼
Recipient taps play → audioplayers streams audio from Firebase Storage URL
```

---

### 10.3 End-to-End: User Login

```
User enters email + password → taps Login
        │
        ▼
AuthController.signIn(email, password)
        │
        ▼
AuthService.signIn(email, password)
        │
        ▼
FirebaseAuth.signInWithEmailAndPassword()
        │
        ├── Success → returns UserCredential with uid
        │       │
        │       ▼
        │   Firestore: Update users/{uid} → isOnline: true
        │       │
        │       ▼
        │   Navigate to ChatListScreen
        │
        └── Failure → throw FirebaseAuthException
                │
                ▼
            Show error SnackBar ("Wrong password" / "User not found")
```

---

### 10.4 End-to-End: Contact Matching

```
User opens NewChatScreen
        │
        ▼
ContactsController.getContactsWithAppStatus()
        │
        ▼
Load all contacts from Firestore: users/{uid}/contacts/
        │
        ▼
For each contact, query Firestore: users where phone == contact.phone
        │
        ├── Match found → add to "onApp" list
        └── No match → add to "notOnApp" list
        │
        ▼
NewChatScreen shows two sections:
  - "Contacts on App" → Message button
  - "Invite to App" → Invite via SMS button
```

---

### 10.5 End-to-End: App Lock

```
App comes to foreground (resumed from background)
        │
        ▼
AppLockController.needsReauthentication()
        │  Checks: isAppLockEnabled AND timeSinceLastAuth > 30 seconds
        │
        ├── No → Continue to ChatListScreen normally
        │
        └── Yes → Show AppLockScreen
                │
                ▼
            AppLockService.authenticate()
                │  Calls local_auth biometric prompt
                │
                ├── Success → Navigate to ChatListScreen
                └── Failure → Stay on AppLockScreen, show error
```

---

## 11. Important Functions

This section explains the most important functions in the codebase.

---

### 11.1 `AuthController.signUp()`

**File:** `lib/controllers/auth_controller.dart`

**Purpose:** Registers a new user and saves their profile.

**Steps:**
1. Calls `AuthService.signUp(email, password)` to create the Firebase Auth account.
2. Gets the `uid` from the returned `UserCredential`.
3. Creates a `UserModel` with all profile fields.
4. Saves the `UserModel` to Firestore at `users/{uid}`.
5. Calls `notifyListeners()` to update the UI.

---

### 11.2 `ChatController.getOrCreateChat()`

**File:** `lib/controllers/chat_controller.dart`

**Purpose:** Gets an existing chat between two users, or creates a new one if it doesn't exist.

**Steps:**
1. Generates the `chatId` by sorting the two UIDs and joining with `_`.
2. Checks if a document exists at `chats/{chatId}`.
3. If it exists, returns the existing `ChatModel`.
4. If not, creates a new chat document with both UIDs in `participants`.
5. Returns the `chatId` so the screen can navigate to `ChatScreen`.

**Why this is important:** This ensures two users always share exactly one chat, no matter who initiates it.

---

### 11.3 `ChatService.sendMessage()`

**File:** `lib/services/chat_service.dart`

**Purpose:** Saves a message to Firestore and updates the chat's last message info.

**Steps:**
1. Adds the message document to `chats/{chatId}/messages/`.
2. Updates the parent `chats/{chatId}` document with:
   - `lastMessage`: the message content or type label
   - `lastMessageTime`: current timestamp
   - `lastMessageSenderId`: sender's UID
   - `unreadCount`: increments the recipient's count using `FieldValue.increment(1)`

**Code snippet:**
```dart
Future<void> sendMessage(String chatId, MessageModel message) async {
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
  
  // Add message to subcollection
  await chatRef.collection('messages').doc(message.messageId).set(message.toMap());
  
  // Update chat document
  await chatRef.update({
    'lastMessage': message.content,
    'lastMessageType': message.type,
    'lastMessageTime': message.timestamp,
    'lastMessageSenderId': message.senderId,
    'unreadCount.${recipientId}': FieldValue.increment(1),
  });
}
```

---

### 11.4 `ChatService.markMessagesAsRead()`

**File:** `lib/services/chat_service.dart`

**Purpose:** Marks all unread messages as read when a user opens a chat.

**Steps:**
1. Queries all messages in `chats/{chatId}/messages/` where `isRead == false` and `senderId != currentUserId`.
2. Uses a Firestore `WriteBatch` to update all of them at once (efficient, atomic).
3. Sets `isRead: true` and `status: "read"` on each message.
4. Resets `unreadCount[currentUserId]` to `0` in the chat document.

**Why WriteBatch?** A batch write sends all updates in a single network request, which is faster and ensures all updates succeed or fail together.

---

### 11.5 `StorageService.uploadChatImage()`

**File:** `lib/services/storage_service.dart`

**Purpose:** Uploads an image file to Firebase Storage and returns the download URL.

**Steps:**
1. Creates a storage reference at `chat_images/{chatId}/{uuid}.jpg`.
2. Calls `ref.putFile(imageFile)` to upload.
3. Waits for the upload to complete.
4. Calls `ref.getDownloadURL()` to get the public URL.
5. Returns the URL to the controller.

---

### 11.6 `ContactsController.getContactsWithAppStatus()`

**File:** `lib/controllers/contacts_controller.dart`

**Purpose:** Separates saved contacts into those who use the app and those who don't.

**Steps:**
1. Loads all contacts from Firestore.
2. For each contact, queries the `users` collection by phone number.
3. If a user document is found, the contact is "on app" and their `uid` is stored.
4. Returns two lists: `onApp` and `notOnApp`.

**Why this matters:** This is the core feature that makes the contact system useful — it bridges the user's phonebook with the app's user database.

---

### 11.7 `AppLockController.authenticate()`

**File:** `lib/controllers/app_lock_controller.dart`

**Purpose:** Triggers biometric authentication and unlocks the app.

**Steps:**
1. Calls `AppLockService.authenticate()`.
2. `AppLockService` uses `local_auth` to show the biometric prompt.
3. If authentication succeeds, updates `_lastAuthTime` to now.
4. Calls `notifyListeners()` so `AppLockScreen` knows to navigate away.

---

### 11.8 `ThemeController.toggleTheme()`

**File:** `lib/controllers/theme_controller.dart`

**Purpose:** Switches between light and dark mode and saves the preference.

**Steps:**
1. Flips the `_isDarkMode` boolean.
2. Saves the new value to `SharedPreferences`.
3. Calls `notifyListeners()` so `MaterialApp` rebuilds with the new theme.

---

### 11.9 `BlockController.blockUser()`

**File:** `lib/controllers/block_controller.dart`

**Purpose:** Blocks a user so they cannot send messages.

**Steps:**
1. Calls `BlockService.blockUser(blockedUserId)`.
2. `BlockService` adds the `blockedUserId` to the `blockedUsers` list in `blocked_users/{currentUserId}`.
3. Updates the local `_blockedUsers` list in the controller.
4. Calls `notifyListeners()` to update the UI.

---

### 11.10 `AuthController.updateOnlineStatus()`

**File:** `lib/controllers/auth_controller.dart`

**Purpose:** Updates the user's online/offline status in Firestore.

**Steps:**
1. Calls `AuthService.updateUserOnlineStatus(uid, isOnline)`.
2. Updates `isOnline` and `lastSeen` fields in `users/{uid}`.
3. This is called when the app goes to foreground (online) or background/logout (offline).

---

## 12. Common Viva Questions & Answers

This section covers the most likely questions an examiner will ask during a viva presentation.

---

**Q1. What is Flutter and why did you use it?**

Flutter is an open-source UI framework by Google that lets you build apps for Android, iOS, web, and desktop from a single codebase using the Dart language. I used it because it allows writing one codebase that runs on both Android and iOS, it has a rich set of pre-built widgets, and it compiles to native code so the app is fast. It also has excellent Firebase integration through the FlutterFire packages.

---

**Q2. What is Firebase and what services does it provide?**

Firebase is a Backend-as-a-Service (BaaS) platform by Google. It provides cloud services so developers do not need to build and maintain their own servers. In this project, I used three Firebase services:
- **Firebase Auth** — for user registration and login
- **Cloud Firestore** — for storing all data (users, chats, messages) in real time
- **Firebase Storage** — for storing media files like images, voice recordings, and documents

---

**Q3. What is Firestore and how is it different from a regular SQL database?**

Firestore is a NoSQL cloud database. Instead of tables and rows (like SQL), it uses **collections** and **documents**. A collection is like a folder, and a document is like a JSON file inside it. The key differences are:
- Firestore is schema-less — documents in the same collection can have different fields
- Firestore supports real-time listeners — the app gets updates automatically when data changes
- Firestore scales automatically without any server management
- SQL databases use structured tables with fixed columns and support complex JOIN queries; Firestore does not support JOINs

---

**Q4. What is Provider and why did you use it for state management?**

Provider is a state management package for Flutter. It allows you to create objects (called `ChangeNotifier`) that hold data and notify the UI when that data changes. I used Provider because:
- It is the officially recommended solution by the Flutter team
- It is simple to understand and implement
- It avoids passing data down through many widget constructors (called "prop drilling")
- It integrates well with Flutter's widget tree

When a controller calls `notifyListeners()`, all widgets that are listening to that controller automatically rebuild with the new data.

---

**Q5. How does real-time messaging work in your app?**

Real-time messaging works through Firestore's **stream** feature. Instead of the app repeatedly asking the server for new messages (polling), Firestore pushes updates to the app automatically whenever data changes.

In the app, `ChatService.getChatMessages(chatId)` returns a `Stream<List<MessageModel>>`. The `ChatScreen` uses a `StreamBuilder` widget to listen to this stream. When a new message is added to Firestore, the stream emits the updated list and the `StreamBuilder` rebuilds the UI to show the new message. This happens in milliseconds.

---

**Q6. How do you generate a unique chat ID for a conversation between two users?**

The chat ID is generated by taking both users' UIDs, sorting them alphabetically, and joining them with an underscore:

```dart
List<String> ids = [uid1, uid2]..sort();
String chatId = ids.join('_');
```

For example, if user A has UID `"abc"` and user B has UID `"xyz"`, the chat ID is always `"abc_xyz"` regardless of who starts the conversation. This ensures two users always share exactly one chat document in Firestore.

---

**Q7. How do message read receipts work?**

Each message document has a `status` field with three possible values: `"sent"`, `"delivered"`, and `"read"`.

- When a message is created, its status is `"sent"`.
- When the recipient's device receives the message through the Firestore stream, the status is updated to `"delivered"`.
- When the recipient opens the chat screen, `markMessagesAsRead()` is called, which updates all unread messages to `"read"` and sets `isRead: true`.

The sender's chat screen listens to the same stream, so when the status changes to `"read"`, the UI updates to show blue double checkmarks.

---

**Q8. How do you handle voice messages?**

Voice messages use two packages:
- **flutter_sound** — for recording audio from the microphone
- **audioplayers** — for playing audio from a URL

When the user holds the microphone button, `flutter_sound` starts recording and saves the audio as an `.aac` file locally. When the user releases the button, recording stops. The file is then uploaded to Firebase Storage using `StorageService.uploadVoiceMessage()`. The returned download URL and the duration are saved in the message document. When the recipient taps play, `audioplayers` streams the audio directly from the Firebase Storage URL.

---

**Q9. How does the contact system work?**

The contact system has two parts:
1. **Saving contacts:** Users can save contacts (name + phone) to Firestore under `users/{uid}/contacts/`. This is like a private phonebook stored in the cloud.
2. **Matching contacts with app users:** When the user opens `NewChatScreen`, the app calls `getContactsWithAppStatus()`. This method loads all saved contacts and queries the `users` Firestore collection to check if any user has a matching phone number. Contacts that match are shown as "on app" with a Message button. Contacts that don't match are shown as "invite to app" with an SMS invite button.

---

**Q10. How does the SMS invite feature work?**

The SMS invite uses the `url_launcher` package. When the user taps "Invite" next to a contact, the app constructs an SMS URI:

```dart
Uri smsUri = Uri(
  scheme: 'sms',
  path: contact.phone,
  queryParameters: {'body': 'Join me on the app!'},
);
await launchUrl(smsUri);
```

This opens the device's native SMS app with the contact's phone number and a pre-filled message. The user can then send the SMS directly.

---

**Q11. How does biometric app lock work?**

The app lock uses the `local_auth` package, which provides access to the device's biometric authentication (fingerprint or face ID).

When the user enables app lock in the profile screen, the setting is saved to `SharedPreferences`. When the app is resumed from the background, `AppLockController.needsReauthentication()` checks if app lock is enabled and if more than 30 seconds have passed since the last authentication. If both are true, `AppLockScreen` is shown and `local_auth` prompts the user for biometric authentication. On success, the app continues normally.

---

**Q12. How does dark mode work and how is it persisted?**

Dark mode is managed by `ThemeController`, which extends `ChangeNotifier`. The current theme preference is stored in `SharedPreferences` (local device storage) so it persists across app restarts.

When the app starts, `ThemeController` reads the saved preference and sets `_isDarkMode` accordingly. The `MaterialApp` widget reads `themeController.isDarkMode` and sets `themeMode` to either `ThemeMode.dark` or `ThemeMode.light`. When the user toggles the theme, `toggleTheme()` flips the boolean, saves it to `SharedPreferences`, and calls `notifyListeners()` to rebuild the UI.

---

**Q13. How do you upload files to Firebase Storage?**

File uploads use the `firebase_storage` package. The process is:
1. Create a storage reference with a unique path (using UUID for the filename).
2. Call `ref.putFile(file)` to start the upload.
3. Wait for the upload task to complete.
4. Call `ref.getDownloadURL()` to get a public HTTPS URL.
5. Save this URL in the Firestore message document.

The URL can then be used by any user to download or display the file.

---

**Q14. What is a ChangeNotifier and how does it work?**

`ChangeNotifier` is a class in Flutter that provides a simple way to notify listeners when data changes. Controllers in this app extend `ChangeNotifier`. When data changes (e.g., a new message arrives), the controller calls `notifyListeners()`. Any widget that is wrapped in a `Consumer` or uses `Provider.of()` to listen to that controller will automatically rebuild.

This is the core mechanism of the Provider state management pattern.

---

**Q15. How do you handle user authentication state across app restarts?**

Firebase Auth automatically persists the user's session on the device. When the app starts, `FirebaseAuth.instance.currentUser` returns the logged-in user if the session is still valid. The app also listens to `FirebaseAuth.instance.authStateChanges()`, which is a stream that emits the current user whenever the auth state changes (login or logout). Based on this, the app navigates to either `LoginScreen` or `ChatListScreen`.

---

**Q16. What is a Firestore WriteBatch and why did you use it?**

A `WriteBatch` is a way to perform multiple Firestore write operations as a single atomic transaction. "Atomic" means either all operations succeed or none of them do — there is no partial update.

I used `WriteBatch` in `markMessagesAsRead()` because it needs to update potentially many message documents at once. Using a batch is more efficient (one network request instead of many) and safer (all messages are marked as read together, not one by one).

---

**Q17. How does the unread message count work?**

The `chats/{chatId}` document has an `unreadCount` field which is a map: `{"uid1": 3, "uid2": 0}`. Each key is a user's UID and the value is their unread count.

When a message is sent, the recipient's count is incremented using `FieldValue.increment(1)` in Firestore. When the recipient opens the chat, `markMessagesAsRead()` resets their count to `0`. The chat list screen reads this map and displays the count as a badge on the chat tile.

---

**Q18. How do group chats differ from one-on-one chats in your data model?**

In the `ChatModel`, there is an `isGroup` boolean field. For group chats:
- `isGroup` is `true`
- `groupName` and `groupPhotoUrl` fields are populated
- `participants` contains more than two UIDs
- Message bubbles show the `senderName` field so users know who sent each message
- The `chatId` is a UUID (not derived from UIDs) since there can be many participants

For one-on-one chats, `isGroup` is `false`, `groupName` is empty, and the `chatId` is derived from the two participants' UIDs.

---

**Q19. How do you handle permissions for camera, microphone, and storage?**

Permissions are declared in `AndroidManifest.xml` for Android and `Info.plist` for iOS. At runtime, the `permission_handler` package is used to request permissions before accessing the camera, microphone, or storage.

For example, before recording a voice message:
```dart
PermissionStatus status = await Permission.microphone.request();
if (status.isGranted) {
  // Start recording
} else {
  // Show error message
}
```

---

**Q20. What happens if two users try to create a chat at the same time?**

Because the chat ID is deterministic (derived from sorted UIDs), both users will try to create a document at the same path. Firestore handles this gracefully — the `set()` operation with `SetOptions(merge: true)` will create the document if it doesn't exist, or merge with the existing one if it does. This prevents duplicate chat documents.

---

**Q21. How does the app know if a user is online?**

The `users/{uid}` document has `isOnline` (boolean) and `lastSeen` (timestamp) fields. When a user opens the app, `AuthController.updateOnlineStatus(true)` is called, setting `isOnline: true`. When they log out or the app goes to the background, `updateOnlineStatus(false)` is called, setting `isOnline: false` and updating `lastSeen` to the current time.

In `ChatScreen`, the app bar shows "Online" if `isOnline` is true, or "Last seen [time]" if false, by listening to `ChatService.isUserOnline(uid)` stream.

---

**Q22. What is `cached_network_image` and why is it used?**

`cached_network_image` is a Flutter package that downloads images from a URL and caches them on the device. Without caching, every time a profile photo or chat image is displayed, it would be downloaded again from Firebase Storage, which is slow and wastes data.

With `CachedNetworkImage`, the image is downloaded once and stored locally. The next time it is displayed, it loads from the local cache instantly. It also shows a placeholder while loading and handles errors gracefully.

---

**Q23. How do you prevent a blocked user from sending messages?**

Before displaying the message input in `ChatScreen`, the app checks `BlockController.isUserBlocked(otherUserId)`. If the other user is blocked, the input field is hidden and replaced with a message like "You have blocked this user." 

Additionally, `BlockService.isCurrentUserBlockedBy(otherUserId)` checks if the current user has been blocked by the other person. If so, the input is also disabled.

---

**Q24. What is the difference between a Service and a Controller in your architecture?**

- A **Service** is a class that only handles direct communication with external APIs (Firebase, device APIs). It has no knowledge of the UI and does not hold any state. It just performs operations and returns results.

- A **Controller** is a class that extends `ChangeNotifier` and contains the business logic. It uses services to perform operations, holds the app's state (like the current user, list of chats), and calls `notifyListeners()` to update the UI.

This separation makes the code easier to test and maintain. If Firebase is replaced with a different backend, only the services need to change — the controllers and UI remain the same.

---

**Q25. How would you improve this app if you had more time?**

Several improvements could be made:
1. **Push notifications** — Use Firebase Cloud Messaging (FCM) to send notifications when a new message arrives, even when the app is closed.
2. **End-to-end encryption** — Encrypt messages so only the sender and recipient can read them.
3. **Message reactions** — Allow users to react to messages with emojis.
4. **Message forwarding and reply** — Allow replying to specific messages or forwarding them.
5. **Video calls** — The `flutter_webrtc` package is already included as a dependency, which could be used to implement video calling.
6. **Firestore security rules** — Add proper server-side security rules to prevent unauthorized data access.
7. **Pagination** — Load messages in pages instead of all at once to improve performance in long chats.
8. **Typing indicators** — Show "typing..." when the other user is composing a message.

---

**Q26. What is `uuid` package used for?**

The `uuid` package generates universally unique identifiers (UUIDs). In this app, it is used to generate unique IDs for messages and contacts:

```dart
String messageId = const Uuid().v4();
// Example: "550e8400-e29b-41d4-a716-446655440000"
```

This ensures every message and contact has a unique ID that will never collide with another, even if generated on different devices at the same time.

---

**Q27. How does file sharing work for non-image files?**

File sharing uses the `file_picker` package to let the user browse and select any file type. Once selected, `StorageService.uploadFile()` uploads it to Firebase Storage under `chat_files/{chatId}/{filename}`. The message document stores the `fileName`, `fileSize`, `fileExtension`, and `mediaUrl`. In the chat screen, file messages are displayed as a card showing the file icon, name, and size. Tapping the card opens the file URL using `url_launcher`, which either downloads the file or opens it in the appropriate app.

---

**Q28. What is `SharedPreferences` and what do you use it for?**

`SharedPreferences` is a Flutter package that provides simple key-value storage on the device. It is used for storing small pieces of data that need to persist across app restarts but do not need to be in the cloud.

In this app, it is used for:
- **Dark mode preference** — `ThemeController` saves `isDarkMode: true/false`
- **App lock setting** — `AppLockController` saves `isAppLockEnabled: true/false`

It is not suitable for large or complex data — that is what Firestore is for.

---

*End of Documentation*

---

> **Document prepared for:** University Viva Presentation
> **Project:** Facebook Messenger Clone
> **Framework:** Flutter + Firebase
> **Author:** [Your Name]
> **Date:** 2024
