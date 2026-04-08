import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/block_service.dart';

class BlockController extends ChangeNotifier {
  final BlockService _blockService = BlockService();

  List<String> _blockedUsers = [];
  List<Map<String, dynamic>> _blockedUsersDetails = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<String> get blockedUsers => _blockedUsers;
  List<Map<String, dynamic>> get blockedUsersDetails => _blockedUsersDetails;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Initialize blocked users listener
  void initializeBlockedUsers() {
    _setLoading(true);

    // Listen to blocked users details
    _blockService.getBlockedUsersDetails().listen(
      (blockedUsers) {
        _blockedUsersDetails = blockedUsers;
        _blockedUsers = blockedUsers
            .map((user) => user['uid'] as String)
            .toList();
        _setLoading(false);
      },
      onError: (error) {
        _setError('Error loading blocked users: ${error.toString()}');
        _setLoading(false);
      },
    );
  }

  // Block user
  Future<bool> blockUser(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _blockService.blockUser(userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Unblock user
  Future<bool> unblockUser(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _blockService.unblockUser(userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      return await _blockService.isUserBlocked(userId);
    } catch (e) {
      developer.log('Error checking if user is blocked: $e');
      return false;
    }
  }

  // Check if current user is blocked by another user
  Future<bool> isCurrentUserBlockedBy(String userId) async {
    try {
      return await _blockService.isCurrentUserBlockedBy(userId);
    } catch (e) {
      developer.log('Error checking if current user is blocked: $e');
      return false;
    }
  }

  // Convert blocked user details to UserModel
  List<UserModel> getBlockedUserModels() {
    return _blockedUsersDetails.map((userData) {
      return UserModel(
        uid: userData['uid'] ?? '',
        email: userData['email'] ?? '',
        name: userData['name'] ?? '',
        photoUrl: userData['photoUrl'],
        phone: userData['phone'],
        isOnline: userData['isOnline'] ?? false,
        lastSeen:
            (userData['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdAt:
            (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }
}
