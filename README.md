# Messenger App — Project Report

**Course / Project:** Software Quality — WhatsApp-Style Mobile Messenger  
**Version:** 1.1.0+2  
**Platform:** Flutter (Android / iOS / Desktop targets)  
**Backend:** Firebase (Auth, Firestore, Storage, FCM) + optional Supabase media + Zego calls

---

## 1. Project Overview

Yeh app ek **WhatsApp-inspired messenger** hai jo real-time chat, groups, stories (status), voice/video calls, privacy settings, aur app lock provide karti hai. UI blue accent (`#0084FF`) ke sath WhatsApp jaisa layout follow karti hai — 3 bottom tabs: **Chats**, **Stories**, **Calls**.

| Item | Detail |
|------|--------|
| App name | Messenger App (`facebook_messanger`) |
| Auth | Email / password (Firebase Auth) |
| Database | Cloud Firestore |
| Media | Firebase Storage (+ Supabase optional) |
| Push | Firebase Cloud Messaging |
| Calls | ZegoUIKit (voice & video 1:1) |

---

## 2. Main Features (Implemented)

### Chats
- 1:1 aur **group** conversations
- Message types: **text, image, voice, file**
- **Reply**, **forward**, **emoji reactions**, **pin**, **star**
- Delete for me / for everyone
- Typing indicator, read/delivered status
- Chat list filters: All, Unread, Favorites, Groups, Archived
- Pin, mute, archive, favorite, search in chat
- Voice recording, camera/gallery, file picker
- Chat wallpaper & font size (`Chat Settings`)

### Stories (Status)
- Text, photo, aur video stories (24-hour expiry)
- Viewers list (kis ne dekha)
- Delete status / delete all statuses
- Stories privacy (Everyone / Contacts / Nobody)
- Search aur menu (Privacy, Settings)

### Calls
- 1:1 **voice** aur **video** (Zego — `.env` keys required)
- Call history screen + Calls tab
- Search calls, keypad, schedule reminder (UI)
- Clear all call logs

### Contacts & Profile
- Saved contacts, user search, contact info screen
- Profile view/edit, profile photo upload
- Audio / video shortcuts from contact info

### Privacy & Security
- Last seen, profile photo, about, online status, stories privacy
- Blocked users list
- **App Lock:** 4-digit PIN + optional biometric
- Dark mode

### Notifications
- FCM push on new messages
- Local notifications + tap to open chat

---

## 3. Technology Stack

```
Flutter 3.x  |  Provider (state)  |  Firebase Suite  |  Supabase (optional)
ZegoUIKit    |  flutter_sound     |  cached_network_image  |  local_auth
```

| Layer | Packages / Services |
|-------|---------------------|
| UI | Material Design, custom theme (`AppTheme`) |
| State | `provider` — Auth, Chat, Story, Call, Theme, AppLock controllers |
| Backend | `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging` |
| Calls | `zego_uikit_prebuilt_call` |
| Security | `flutter_secure_storage`, `crypto` (PIN hash), `local_auth` |

---

## 4. Project Structure

```
lib/
├── main.dart
├── controllers/          # Auth, Chat, Story, Call, AppLock, Theme, ...
├── services/             # Firebase, storage, notifications, privacy, ...
├── models/               # User, Chat, Message, Story, Call, ...
├── screens/
│   ├── home/             # 3-tab shell (Chats | Stories | Calls)
│   ├── chat/             # Chat list & conversation
│   ├── group/            # Create group, group info
│   ├── contacts/         # Contacts CRUD
│   ├── settings/         # Privacy, app lock, chat appearance
│   └── auth/             # Login, signup, PIN screens
├── features/
│   ├── stories/          # Stories tab, viewer, text story
│   └── calls/            # Calls tab, call helper
└── widgets/              # Chat tile, message bubble, menus
```

---

## 5. Screenshots (App UI)

<img width="200" height="600" alt="Main dashbord" src="https://github.com/user-attachments/assets/5d84b5bc-a670-4031-95bc-960ca41438c3" /><img width="200" height="600" alt="WhatsApp Image 2026-05-21 at 11 53 41" src="https://github.com/user-attachments/assets/b9b799f0-1ac6-4bf7-a4c5-b79b42c083d5" /><img width="200" height="600" alt="WhatsApp Image 2026-05-21 at 11 53 40" src="https://github.com/user-attachments/assets/a31b8720-1787-45df-8c7d-ce795f0c7dd3" /><img width="200" height="600" alt="WhatsApp Image 2026-05-21 at 11 53 39 (1)" src="https://github.com/user-attachments/assets/1c3aef94-ffb1-4643-9633-e3d0bb6f605f" />






---

## 6. Comparison with Real WhatsApp (Summary)

| Area | WhatsApp | This project |
|------|----------|--------------|
| Chat & groups | Full | **~65%** — core messaging strong |
| Stories / Status | Full | **~70%** — text/photo/video + viewers |
| Calls | Full + incoming | **~35%** — Zego 1:1; weak incoming/group |
| E2E encryption | Yes | **No** (UI text only; Firestore plain text) |
| Communities / Channels | Yes | **No** |
| Backup / multi-device | Yes | **No** |

**Conclusion:** App **WhatsApp-style MVP** hai — daily messaging, status, aur basic calls ke liye suitable; production WhatsApp replacement nahi jab tak E2E, incoming calls, aur backup add na hon.

---

## 7. Setup & Run

### Prerequisites
- Flutter SDK 3.9+
- Firebase project (Auth, Firestore, Storage, FCM)
- Optional: Supabase URL/keys, Zego App ID & Sign in `.env`

### Steps

```bash
cd messenger_app
flutter pub get
# Add google-services.json (Android) & GoogleService-Info.plist (iOS)
# Create .env from example with Firebase / Zego / Supabase keys
flutter run
```

### Firestore rules
Deploy `firestore.rules` from project root (Firebase Console → Firestore → Rules → Publish).  
**Do not** keep old open rule `match /{document=**} { allow read, write: if request.auth != null; }` — replace entirely.

### Release APK (example)
```bash
flutter build apk --release
```

---

## 8. Known Limitations

- End-to-end encryption **implemented nahi** (privacy screen par text display hai)
- Incoming call UI / signaling incomplete
- Group calls nahi
- Phone contact sync nahi (manual saved contacts)
- Cloud backup / restore nahi
- Disappearing messages partial (setting save; har message par apply weak)

---

## 9. Documentation Files (Repo)

| File | Purpose |
|------|---------|
| `FIREBASE_SETUP.md` | Firebase configuration |
| `SUPABASE_SETUP.md` | Supabase media setup |
| `ZEGO_SETUP.md` | Voice/video calls |
| `SECURITY_GUIDE.md` | Security notes |
| `firestore.rules` | Firestore security rules |

---

## 10. Version History

| Version | Notes |
|---------|-------|
| 1.1.0+2 | 3-tab UI, Stories, Calls tab, app lock, privacy, profile photo fixes |
| Earlier | Firebase chat MVP, groups, reactions |

---

<p align="center">
  <b>Messenger App — SoftwareConstruction and quality Project</b><br>
  <sub>Flutter · Firebase · WhatsApp-inspired UI</sub>
</p>
