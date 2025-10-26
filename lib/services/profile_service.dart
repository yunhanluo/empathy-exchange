import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image to Firebase Storage
  Future<String> uploadProfilePicture(Uint8List imageBytes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final ref =
        _storage.ref().child('profile_pictures').child('${user.uid}.jpg');

    final uploadTask = ref.putData(imageBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Update profile with image URL
  Future<void> updateProfilePicture(XFile imageFile) async {
    print('🔥 updateProfilePicture: Starting Firebase Storage upload...');
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    print('🔥 updateProfilePicture: Reading image bytes...');
    final bytes = await imageFile.readAsBytes();
    print('🔥 updateProfilePicture: Image size: ${bytes.length} bytes');

    print('🔥 updateProfilePicture: Uploading to Firebase Storage...');
    String downloadUrl;
    try {
      downloadUrl = await uploadProfilePicture(bytes);
      print('🔥 updateProfilePicture: Got download URL: $downloadUrl');
    } catch (e) {
      print('🔥 updateProfilePicture: Firebase Storage upload failed: $e');
      throw Exception('Firebase Storage upload failed: $e');
    }

    print('🔥 updateProfilePicture: Updating Firestore with URL...');
    await _firestore.collection('users').doc(user.uid).update({
      'profilePictureUrl': downloadUrl,
    });
    print('🔥 updateProfilePicture: Firebase Storage upload completed!');
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Stream user profile data for real-time updates
  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      print('updateUserProfile: Starting...');
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('updateUserProfile: User UID: ${user.uid}');
      print('updateUserProfile: Calling Firestore update...');

      // Try update() first - much faster
      await _firestore.collection('users').doc(user.uid).update(profileData);
      print('updateUserProfile: Firestore update completed');
    } catch (e) {
      print('updateUserProfile: Update failed - $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Pick image from gallery or camera
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      // On web, both camera and gallery often use the same file picker
      // So we'll handle this differently for web vs mobile
      if (kIsWeb) {
        // On web, always use gallery source but show different UI
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, // Web always uses gallery
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 70,
        );

        return image;
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 70,
          preferredCameraDevice: source == ImageSource.camera
              ? CameraDevice.front
              : CameraDevice.rear,
        );

        return image;
      }
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  // Convert image to base64
  Future<String> imageToBase64(XFile imageFile) async {
    try {
      print('Starting base64 conversion...');
      final bytes = await imageFile.readAsBytes();
      print('Image size: ${bytes.length} bytes');

      // For very large images, we might want to compress further
      if (bytes.length > 500000) {
        // 500KB
        print('Large image detected, consider further compression');
      }

      String base64String = base64Encode(bytes);
      print('Base64 conversion completed. Length: ${base64String.length}');
      return base64String;
    } catch (e) {
      print('Base64 conversion error: $e');
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  // Convert base64 to image bytes
  Uint8List base64ToImageBytes(String base64String) {
    return base64Decode(base64String);
  }

  // Get profile picture URL from Firebase Storage
  Future<String?> getProfilePicture(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data[
            'profilePictureUrl']; // Changed from 'profilePicture' to 'profilePictureUrl'
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get profile picture: $e');
    }
  }

  // Create or update user document
  Future<void> createOrUpdateUserDocument() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      Map<String, dynamic> userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
    } catch (e) {
      throw Exception('Failed to create/update user document: $e');
    }
  }

  // Update user online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail
    }
  }
}
