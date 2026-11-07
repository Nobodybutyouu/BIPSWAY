import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> currentAppUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return readAppUser(firebaseUser.uid);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
    required AppRole expectedRole,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException('Unable to sign in. Please try again.');
      }
      // The local admin bootstrap changes a custom claim. Force a refresh so
      // this sign-in sees the new role immediately.
      await user.getIdToken(true);
      final profile = await readAppUser(user.uid);
      if (profile.status == AccountStatus.disabled) {
        await _auth.signOut();
        throw const AuthServiceException('Your account has been disabled.');
      }
      if (profile.role != expectedRole) {
        await _auth.signOut();
        throw AuthServiceException(
          'This account is registered as ${profile.role.name}, not ${expectedRole.name}.',
        );
      }
      return profile;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    }
  }

  Future<AppUser> signUp({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String affiliation,
    String? purpose,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final existing = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: normalizedUsername)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const AuthServiceException('That username is already in use.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException('Unable to create the account.');
      }
      final profile = AppUser(
        id: user.uid,
        role: AppRole.navigator,
        username: username.trim(),
        fullName: fullName.trim(),
        email: email.trim(),
        affiliation: affiliation,
        purpose: purpose,
        status: AccountStatus.active,
        notificationPrefs: const {
          'mapUpdates': false,
          'campusAnnouncements': false,
        },
        saveSearchHistory: true,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(profile.toFirestore());
      await user.sendEmailVerification();
      return profile;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageForAuthError(error));
    }
  }

  Future<AppUser> readAppUser(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      throw const AuthServiceException('Your account profile could not be found.');
    }
    final profile = AppUser.fromFirestore(snapshot);
    final token = await _auth.currentUser?.getIdTokenResult();
    final claimRole = token?.claims?['role'];
    if (claimRole is String && claimRole != profile.role.name) {
      throw const AuthServiceException(
        'Your account role is inconsistent. Please contact an administrator.',
      );
    }
    return profile;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  String _messageForAuthError(FirebaseAuthException error) {
    if (error.code == 'user-disabled') {
      return 'Your account has been disabled.';
    }
    return switch (error.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' =>
        'Invalid email or password.',
      'email-already-in-use' => 'An account already exists for this email.',
      'weak-password' => 'Password is too weak.',
      'invalid-email' => 'Please enter a valid Email Address.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }
}
