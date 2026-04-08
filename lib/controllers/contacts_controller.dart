import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/local_contact_model.dart';
import '../models/user_model.dart';

class ContactsController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<LocalContact> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  List<LocalContact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  String? get _currentUid => _auth.currentUser?.uid;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // Load saved local contacts (name + phone)
  Future<void> loadContacts() async {
    if (_currentUid == null) return;
    _setLoading(true);
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('contacts')
          .get();
      _contacts = snap.docs.map((d) => LocalContact.fromMap(d.data())).toList();
      _contacts.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _errorMessage = 'Failed to load contacts.';
    }
    _setLoading(false);
  }

  // Save a new contact with full details
  Future<bool> addContact({
    required String name,
    required String phone,
    String? email,
    String? photoUrl,
    String? address,
    String? company,
    String? jobTitle,
    String? notes,
    String? nickname,
    DateTime? birthday,
  }) async {
    if (_currentUid == null) return false;
    final normalized = _normalizePhone(phone);

    if (_contacts.any((c) => _normalizePhone(c.phone) == normalized)) {
      _errorMessage = 'A contact with this number already exists.';
      notifyListeners();
      return false;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final contact = LocalContact(
      id: id,
      name: name,
      phone: normalized,
      email: email,
      photoUrl: photoUrl,
      address: address,
      company: company,
      jobTitle: jobTitle,
      notes: notes,
      nickname: nickname,
      birthday: birthday,
    );

    try {
      await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('contacts')
          .doc(id)
          .set(contact.toMap());

      _contacts.add(contact);
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      _successMessage = '$name saved to contacts.';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save contact.';
      notifyListeners();
      return false;
    }
  }

  // Update existing contact
  Future<bool> updateContact(LocalContact contact) async {
    if (_currentUid == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('contacts')
          .doc(contact.id)
          .update(contact.toMap());

      final index = _contacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        _contacts[index] = contact;
        _contacts.sort((a, b) => a.name.compareTo(b.name));
      }
      _successMessage = '${contact.name} updated.';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update contact.';
      notifyListeners();
      return false;
    }
  }

  // Remove a contact
  Future<void> removeContact(String id) async {
    if (_currentUid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('contacts')
          .doc(id)
          .delete();
      _contacts.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to remove contact.';
      notifyListeners();
    }
  }

  // Cross-reference saved contacts with app users by phone number.
  // Returns a map with two keys:
  //   'onApp'    -> List<Map> with keys 'contact' (LocalContact) and 'user' (UserModel)
  //   'notOnApp' -> List<LocalContact>
  Future<Map<String, dynamic>> getContactsWithAppStatus() async {
    final List<Map<String, dynamic>> onApp = [];
    final List<LocalContact> notOnApp = [];

    for (final contact in _contacts) {
      final normalized = _normalizePhone(contact.phone);
      try {
        final snap = await _firestore
            .collection('users')
            .where('phone', isEqualTo: normalized)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          final user = UserModel.fromMap(snap.docs.first.data());
          // Don't show current user
          if (user.uid != _currentUid) {
            onApp.add({'contact': contact, 'user': user});
          }
        } else {
          notOnApp.add(contact);
        }
      } catch (_) {
        notOnApp.add(contact);
      }
    }

    return {'onApp': onApp, 'notOnApp': notOnApp};
  }

  String _normalizePhone(String phone) {
    // Strip all non-digit characters for consistent comparison
    return phone.replaceAll(RegExp(r'\D'), '');
  }
}
