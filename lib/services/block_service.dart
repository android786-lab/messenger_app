import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';

class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Block a user
  Future<void> blockUser(String userIdToBlock) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(userIdToBlock)
          .set({
            'blockedAt': Timestamp.fromDate(DateTime.now()),
            'blockedUserId': userIdToBlock,
          });
    } catch (e) {
      throw Exception('Error blocking user: ${e.toString()}');
    }
  }

  // Unblock a user
  Future<void> unblockUser(String userIdToUnblock) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(userIdToUnblock)
          .delete();
    } catch (e) {
      throw Exception('Error unblocking user: ${e.toString()}');
    }
  }

  // Get list of blocked users
  Stream<List<String>> getBlockedUsers() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUserId)
        .collection('blocked_users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      developer.log('Error checking if user is blocked: $e');
      return false;
    }
  }

  // Check if current user is blocked by another user
  Future<bool> isCurrentUserBlockedBy(String otherUserId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(otherUserId)
          .collection('blocked_users')
          .doc(currentUserId)
          .get();
      return doc.exists;
    } catch (e) {
      developer.log('Error checking if current user is blocked: $e');
      return false;
    }
  }

  // Get blocked user details
  Stream<List<Map<String, dynamic>>> getBlockedUsersDetails() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUserId)
        .collection('blocked_users')
        .snapshots()
        .asyncMap((blockedUsersSnapshot) async {
          List<Map<String, dynamic>> blockedUsersDetails = [];

          for (var blockedDoc in blockedUsersSnapshot.docs) {
            String blockedUserId = blockedDoc.id;

            try {
              DocumentSnapshot userDoc = await _firestore
                  .collection(AppConstants.usersCollection)
                  .doc(blockedUserId)
                  .get();

              if (userDoc.exists) {
                Map<String, dynamic> userData =
                    userDoc.data() as Map<String, dynamic>;
                userData['blockedAt'] = blockedDoc.get('blockedAt');
                blockedUsersDetails.add(userData);
              }
            } catch (e) {
              developer.log(
                'Error fetching user details for $blockedUserId: $e',
              );
            }
          }

          return blockedUsersDetails;
        });
  }
}
