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

  bool _contactsLoaded = false;

  // Load saved local contacts — skips fetch if already cached
  Future<void> loadContacts({bool forceRefresh = false}) async {
    if (_currentUid == null) return;
    if (_contactsLoaded && !forceRefresh) return; // use cache
    _setLoading(true);
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('contacts')
          .get();
      _contacts = snap.docs.map((d) => LocalContact.fromMap(d.data())).toList();
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      _contactsLoaded = true;
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
      _contactsLoaded = true;
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

  // Cross-reference saved contacts with app users.
  // Uses parallel Firestore queries instead of sequential per-contact reads.
  Future<Map<String, dynamic>> getContactsWithAppStatus() async {
    if (_contacts.isEmpty) return {'onApp': [], 'notOnApp': []};

    final List<Map<String, dynamic>> onApp = [];
    final List<LocalContact> notOnApp = [];

    // Build a map of normalized phone → contact for O(1) lookup
    final phoneToContact = <String, LocalContact>{};
    for (final c in _contacts) {
      final n = _normalizePhone(c.phone);
      if (n.isNotEmpty) phoneToContact[n] = c;
    }

    final phones = phoneToContact.keys.toList();
    if (phones.isEmpty) {
      return {'onApp': [], 'notOnApp': List<LocalContact>.from(_contacts)};
    }

    // Firestore 'whereIn' supports up to 30 values per query — chunk if needed
    const chunkSize = 30;
    final foundPhones = <String>{};

    for (int i = 0; i < phones.length; i += chunkSize) {
      final chunk = phones.sublist(
          i, i + chunkSize > phones.length ? phones.length : i + chunkSize);
      try {
        final snap = await _firestore
            .collection('users')
            .where('phone', whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final user = UserModel.fromMap(doc.data());
          if (user.uid == _currentUid) continue; // skip self
          final contact = phoneToContact[user.phone ?? ''];
          if (contact != null) {
            onApp.add({'contact': contact, 'user': user});
            foundPhones.add(user.phone ?? '');
          }
        }
      } catch (_) {}
    }

    // Contacts not found on app
    for (final c in _contacts) {
      final n = _normalizePhone(c.phone);
      if (!foundPhones.contains(n)) {
        notOnApp.add(c);
      }
    }

    return {'onApp': onApp, 'notOnApp': notOnApp};
  }

  String _normalizePhone(String phone) {
    // Strip all non-digit characters for consistent comparison
    return phone.replaceAll(RegExp(r'\D'), '');
  }
}
