import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Normalize phone digits only for consistent lookup
        final normalizedPhone = phone?.replaceAll(RegExp(r'\D'), '');

        UserModel userModel = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          phone: normalizedPhone,
          isOnline: true,
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(userModel.toMap());

        return userModel;
      }
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
    return null;
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Update user online status
        await updateUserOnlineStatus(user.uid, true);

        // Get user data from Firestore
        DocumentSnapshot doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();

        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
      }
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (currentUser != null) {
        await updateUserOnlineStatus(currentUser!.uid, false);
      }
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Update user online status — also stamps lastSeen so stale presence can be detected
  Future<void> updateUserOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      developer.log('Error updating online status: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      developer.log('Error getting user: $e');
    }
    return null;
  }

  // Search users by email, name, or phone — runs parallel queries and merges
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final q = query.trim().toLowerCase();
      final qDigits = q.replaceAll(RegExp(r'\D'), ''); // digits only for phone

      // Run up to 3 queries in parallel
      final futures = <Future<QuerySnapshot>>[];

      // 1. Email prefix search
      futures.add(
        _firestore
            .collection(AppConstants.usersCollection)
            .where('email', isGreaterThanOrEqualTo: q)
            .where('email', isLessThan: '${q}z')
            .limit(10)
            .get(),
      );

      // 2. Name prefix search (stored lowercase for case-insensitive match)
      //    We also try the original-case query since names may be stored mixed-case
      futures.add(
        _firestore
            .collection(AppConstants.usersCollection)
            .where('name', isGreaterThanOrEqualTo: query.trim())
            .where('name', isLessThan: '${query.trim()}z')
            .limit(10)
            .get(),
      );

      // 3. Phone search (digits only)
      if (qDigits.isNotEmpty) {
        futures.add(
          _firestore
              .collection(AppConstants.usersCollection)
              .where('phone', isGreaterThanOrEqualTo: qDigits)
              .where('phone', isLessThan: '${qDigits}9')
              .limit(10)
              .get(),
        );
      }

      final snapshots = await Future.wait(futures);

      // Merge and deduplicate
      final seen = <String>{};
      final results = <UserModel>[];
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final user =
              UserModel.fromMap(doc.data() as Map<String, dynamic>);
          // Exclude self and duplicates
          if (user.uid != currentUser?.uid && seen.add(user.uid)) {
            results.add(user);
          }
        }
      }

      // Client-side filter: keep only results that actually contain the query
      // (Firestore prefix queries can return false positives at boundaries)
      return results.where((u) {
        final nameLower = u.name.toLowerCase();
        final emailLower = u.email.toLowerCase();
        final phoneDigits = (u.phone ?? '').replaceAll(RegExp(r'\D'), '');
        return nameLower.contains(q) ||
            emailLower.contains(q) ||
            (qDigits.isNotEmpty && phoneDigits.contains(qDigits));
      }).toList();
    } catch (e) {
      developer.log('Error searching users: $e');
      return [];
    }
  }

  // Keep old method as alias for backward compatibility
  Future<List<UserModel>> searchUsersByEmail(String email) =>
      searchUsers(email);

  // Stream user online status in real-time
  Stream<UserModel?> streamUserById(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserModel.fromMap(doc.data() as Map<String, dynamic>);
          }
          return null;
        });
  }

  // Update user profile
  Future<UserModel?> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? photoUrl,
    String? about,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (phone != null) {
        updates['phone'] = phone.replaceAll(RegExp(r'\D'), '');
      }
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (about != null) updates['about'] = about;

      if (updates.isNotEmpty) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update(updates);
      }

      DocumentSnapshot doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      developer.log('Error updating user profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
    return null;
  }
}
