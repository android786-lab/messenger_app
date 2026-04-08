# Facebook Messenger Clone - Setup Instructions

## Project Overview
This is a complete Facebook Messenger-like messaging application built with Flutter and Firebase. The app includes real-time messaging, image sharing, voice messages, group chats, and user authentication.

## Technology Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage
- **State Management**: Provider
- **Target Platform**: Android

## Prerequisites
Before setting up the project, ensure you have the following installed:

1. **Flutter SDK** (3.9.2 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH

2. **Android Studio** or **VS Code** with Flutter extensions

3. **Android SDK** (for Android development)

4. **Git** (for version control)

5. **Node.js** (for Firebase CLI)
   - Download from: https://nodejs.org/

## Step 1: Clone and Setup Flutter Project

### 1.1 Clone the Repository
```bash
git clone <your-repository-url>
cd facebook_messanger
```

### 1.2 Install Flutter Dependencies
```bash
flutter pub get
```

### 1.3 Verify Flutter Installation
```bash
flutter doctor
```
Fix any issues reported by Flutter doctor.

## Step 2: Firebase Project Setup

### 2.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `facebook-messenger-clone` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2.2 Enable Firebase Services

#### Enable Authentication
1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Email/Password** provider
3. Click "Save"

#### Enable Firestore Database
1. Go to **Firestore Database**
2. Click "Create database"
3. Choose "Start in test mode" (we'll configure security rules later)
4. Select your preferred location
5. Click "Done"

#### Enable Firebase Storage
1. Go to **Storage**
2. Click "Get started"
3. Choose "Start in test mode"
4. Select the same location as Firestore
5. Click "Done"

## Step 3: Android App Configuration

### 3.1 Add Android App to Firebase
1. In Firebase Console, click "Add app" and select Android
2. Enter the following details:
   - **Android package name**: `com.example.facebook_messanger`
   - **App nickname**: `Facebook Messenger Clone`
   - **Debug signing certificate SHA-1**: (optional for now)
3. Click "Register app"

### 3.2 Download Configuration File
1. Download the `google-services.json` file
2. Place it in `android/app/` directory of your Flutter project

### 3.3 Configure Android Build Files

#### Update `android/build.gradle.kts`:
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

#### Update `android/app/build.gradle.kts`:
Add the following at the top after existing plugins:
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Add this line
}
```

## Step 4: Install Firebase CLI and FlutterFire

### 4.1 Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 4.2 Login to Firebase
```bash
firebase login
```

### 4.3 Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### 4.4 Configure FlutterFire
```bash
flutterfire configure
```
- Select your Firebase project
- Select platforms: Android (and iOS if needed)
- This will update your `firebase_options.dart` file with actual configuration

## Step 5: Update Firebase Configuration

### 5.1 Update `lib/firebase_options.dart`
Replace the placeholder values with your actual Firebase configuration values from the FlutterFire CLI output.

### 5.2 Verify Firebase Integration
The `lib/main.dart` file should already have Firebase initialization code:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Step 6: Configure Firestore Security Rules

### 6.1 Set Firestore Rules
1. Go to Firebase Console > Firestore Database > Rules
2. Replace the default rules with the following:

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

### 6.2 Set Storage Rules
1. Go to Firebase Console > Storage > Rules
2. Replace with:

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

## Step 7: Android Permissions

### 7.1 Update `android/app/src/main/AndroidManifest.xml`
Add the following permissions before the `<application>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## Step 8: Create Required Directories

### 8.1 Create Asset Directories
```bash
mkdir -p assets/images
mkdir -p assets/icons
```

### 8.2 Add Placeholder Assets (Optional)
You can add app icons and placeholder images to these directories.

## Step 9: Run the Application

### 9.1 Connect Android Device or Start Emulator
- Connect your Android device via USB with Developer Options enabled
- OR start an Android emulator from Android Studio

### 9.2 Check Connected Devices
```bash
flutter devices
```

### 9.3 Run the App
```bash
flutter run
```

## Step 10: Testing the Application

### 10.1 Test Authentication
1. Launch the app
2. Create a new account using the signup screen
3. Login with the created credentials
4. Verify user data is stored in Firestore

### 10.2 Test Messaging
1. Create another user account (use different email)
2. Start a chat between the two users
3. Send text messages and verify real-time updates
4. Test image sharing functionality
5. Test voice message recording and playback

### 10.3 Test Group Chat
1. Create a group chat
2. Add multiple participants
3. Send messages in the group
4. Verify all participants receive messages

## Troubleshooting

### Common Issues and Solutions

#### 1. Firebase Configuration Issues
- **Error**: `FirebaseOptions not configured`
- **Solution**: Run `flutterfire configure` again and ensure `firebase_options.dart` has correct values

#### 2. Android Build Issues
- **Error**: `google-services.json not found`
- **Solution**: Ensure `google-services.json` is in `android/app/` directory

#### 3. Permission Issues
- **Error**: Camera/Storage permissions denied
- **Solution**: Grant permissions manually in device settings or implement runtime permission requests

#### 4. Firestore Permission Denied
- **Error**: `PERMISSION_DENIED: Missing or insufficient permissions`
- **Solution**: Check Firestore security rules and ensure user is authenticated

#### 5. Storage Upload Issues
- **Error**: Storage upload fails
- **Solution**: Check Firebase Storage rules and ensure proper authentication

### Debug Commands
```bash
# Check Flutter installation
flutter doctor -v

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Firebase project
firebase projects:list

# View Firestore data
firebase firestore:indexes

# Check Android build
cd android && ./gradlew build
```

## Project Structure Overview

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
│       └── time_formatter.dart
├── models/
│   ├── user_model.dart
│   ├── message_model.dart
│   └── chat_model.dart
├── services/
│   ├── auth_service.dart
│   ├── chat_service.dart
│   └── storage_service.dart
├── controllers/
│   ├── auth_controller.dart
│   └── chat_controller.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── chat/
│   │   ├── chat_list_screen.dart
│   │   ├── chat_screen.dart
│   │   └── new_chat_screen.dart
│   ├── group/
│   │   └── create_group_screen.dart
│   └── profile/
│       └── profile_screen.dart
├── widgets/
│   ├── custom_button.dart
│   ├── custom_textfield.dart
│   ├── message_bubble.dart
│   └── chat_tile.dart
├── firebase_options.dart
└── main.dart
```

## Features Implemented

### ✅ Core Features
- [x] User Authentication (Login/Signup/Logout)
- [x] Real-time Chat List
- [x] One-to-One Messaging
- [x] Image Sharing
- [x] Voice Messages
- [x] Group Chat
- [x] User Profile Management
- [x] Online Status
- [x] Message Timestamps
- [x] Unread Message Count

### 🎨 UI Features
- [x] Material Design UI
- [x] Custom Theme
- [x] Responsive Layout
- [x] Loading States
- [x] Error Handling
- [x] Input Validation

### 🔧 Technical Features
- [x] Clean Architecture
- [x] State Management (Provider)
- [x] Firebase Integration
- [x] Real-time Updates
- [x] Image Compression
- [x] Audio Recording
- [x] File Upload
- [x] Security Rules

## Next Steps

1. **Add Push Notifications**: Implement Firebase Cloud Messaging for background notifications
2. **Add Message Reactions**: Allow users to react to messages with emojis
3. **Add Message Search**: Implement search functionality across chats
4. **Add Dark Mode**: Implement theme switching
5. **Add Message Encryption**: Add end-to-end encryption for enhanced security
6. **Add Video Calls**: Integrate video calling functionality
7. **Add Story Feature**: Implement Instagram-like story sharing
8. **Add Message Forwarding**: Allow forwarding messages between chats

## Support

If you encounter any issues during setup:

1. Check the troubleshooting section above
2. Verify all Firebase services are properly configured
3. Ensure all dependencies are up to date
4. Check Flutter and Firebase documentation
5. Review Firebase Console for any configuration issues

## License

This project is created for educational purposes as part of the Software Construction & Development (CSE325) course.