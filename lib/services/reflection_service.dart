// lib/services/reflection_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ReflectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'reflections';

  /// Save a new reflection
  Future<String?> saveReflection({
    required String category,
    required DateTime startedAt,
    required Map<String, int> answers,
    required Map<String, dynamic> summary,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final docRef = await _firestore.collection(_collection).add({
        'userId': user.uid,
        'category': category,
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': FieldValue.serverTimestamp(),
        'answers': answers,
        'summary': summary,
      });

      // Update user doc with last reflection timestamp
      await _firestore.collection('users').doc(user.uid).update({
        'lastReflectionDate': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving reflection: $e');
      }
      return null;
    }
  }

  /// Stream of user's reflections (newest first)
  Stream<QuerySnapshot> getUserReflections() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.empty();

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('completedAt', descending: true)
        .snapshots();
  }

  /// Get single reflection by ID
  Future<DocumentSnapshot?> getReflection(String reflectionId) async {
    try {
      return await _firestore.collection(_collection).doc(reflectionId).get();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching reflection: $e');
      }
      return null;
    }
  }

  /// Delete a reflection (only if it belongs to the current user)
  Future<bool> deleteReflection(String reflectionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Security check: confirm ownership
      final doc = await _firestore.collection(_collection).doc(reflectionId).get();
      if (!doc.exists || doc.data()?['userId'] != user.uid) {
        if (kDebugMode) {
          print('Reflection not found or not owned by user');
        }
        return false;
      }

      await _firestore.collection(_collection).doc(reflectionId).delete();

      // Optional cleanup: if no more reflections, remove lastReflectionDate
      final remaining = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (remaining.docs.isEmpty) {
        await _firestore.collection('users').doc(user.uid).update({
          'lastReflectionDate': FieldValue.delete(),
        });
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting reflection: $e');
      }
      return false;
    }
  }
}