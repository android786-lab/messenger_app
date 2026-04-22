import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? phone;
  final String? about;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime createdAt;
  // Privacy: 'everyone' | 'contacts' | 'nobody'
  final String lastSeenPrivacy;
  final String profilePhotoPrivacy;
  final String aboutPrivacy;
  final String onlineStatusPrivacy;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.phone,
    this.about,
    required this.isOnline,
    required this.lastSeen,
    required this.createdAt,
    this.lastSeenPrivacy = 'everyone',
    this.profilePhotoPrivacy = 'everyone',
    this.aboutPrivacy = 'everyone',
    this.onlineStatusPrivacy = 'everyone',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'photoUrl': photoUrl,
        'phone': phone,
        'about': about,
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(lastSeen),
        'createdAt': Timestamp.fromDate(createdAt),
        'lastSeenPrivacy': lastSeenPrivacy,
        'profilePhotoPrivacy': profilePhotoPrivacy,
        'aboutPrivacy': aboutPrivacy,
        'onlineStatusPrivacy': onlineStatusPrivacy,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] ?? '',
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        photoUrl: map['photoUrl'],
        phone: map['phone'],
        about: map['about'],
        isOnline: map['isOnline'] ?? false,
        lastSeen: (map['lastSeen'] as Timestamp).toDate(),
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        lastSeenPrivacy: map['lastSeenPrivacy'] ?? 'everyone',
        profilePhotoPrivacy: map['profilePhotoPrivacy'] ?? 'everyone',
        aboutPrivacy: map['aboutPrivacy'] ?? 'everyone',
        onlineStatusPrivacy: map['onlineStatusPrivacy'] ?? 'everyone',
      );

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    String? phone,
    String? about,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    String? lastSeenPrivacy,
    String? profilePhotoPrivacy,
    String? aboutPrivacy,
    String? onlineStatusPrivacy,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        phone: phone ?? this.phone,
        about: about ?? this.about,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        createdAt: createdAt ?? this.createdAt,
        lastSeenPrivacy: lastSeenPrivacy ?? this.lastSeenPrivacy,
        profilePhotoPrivacy: profilePhotoPrivacy ?? this.profilePhotoPrivacy,
        aboutPrivacy: aboutPrivacy ?? this.aboutPrivacy,
        onlineStatusPrivacy: onlineStatusPrivacy ?? this.onlineStatusPrivacy,
      );
}
