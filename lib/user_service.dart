import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static Future<void> ensureProfile(User user) async {
    final email = user.email;

    if (email == null) {
      throw StateError('An email is required to create your profile.');
    }

    final profileRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final displayName = user.displayName?.trim() ?? '';
    final name = displayName.isEmpty ? 'Student' : displayName;

    await FirebaseFirestore.instance.runTransaction<void>((transaction) async {
      final existingProfile = await transaction.get(profileRef);

      // Keep an existing profile unchanged.
      if (existingProfile.exists) {
        return;
      }

      transaction.set(profileRef, {
        'name': name.length > 100 ? name.substring(0, 100) : name,
        'email': email,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> requestAdminAccess(User user) async {
    final ref = FirebaseFirestore.instance
        .collection('admin_requests')
        .doc(user.uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        return;
      }
      transaction.set(ref, {
        'studentId': user.uid,
        'email': user.email,
        'name': (user.displayName ?? 'Applicant').trim(),
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
