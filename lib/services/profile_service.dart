import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../lib/firebase.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Update profile picture with base64
  Future<void> updateProfilePicture(XFile imageFile) async {
    try {
      print('🔥 updateProfilePicture: Starting base64 conversion...');
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔥 updateProfilePicture: Converting image to base64...');
      final base64Image = await imageToBase64(imageFile);
      print(
          '🔥 updateProfilePicture: Base64 conversion complete. Length: ${base64Image.length}');

      if (user.email == null) throw Exception('User email is null');

      // Store profile picture in Realtime Database using email as key
      print(
          '🔥 updateProfilePicture: Storing in Realtime Database with email: ${user.email}');
      final emailKey =
          user.email!.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      final path = 'profilePictures/$emailKey';

      await FirebaseTools.update(path, {
        'profilePicture': base64Image,
        'email': user.email!,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      print('🔥 updateProfilePicture: Realtime Database update completed!');
    } catch (e) {
      print('🔥 updateProfilePicture: ERROR - $e');
      throw Exception('Failed to update profile picture: $e');
    }
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

  // Get profile picture from Realtime Database using email
  Future<String?> getProfilePicture(String identifier) async {
    try {
      String? email;

      // If identifier is an email, use it directly
      if (identifier.contains('@')) {
        email = identifier;
      } else {
        // Otherwise, it's a UID - get email from Firestore
        print(
            '🔥 getProfilePicture: Identifier is UID, fetching email from Firestore...');
        final doc = await _firestore.collection('users').doc(identifier).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          email = data?['email'] as String?;
        }
      }

      if (email == null) {
        print(
            '🔥 getProfilePicture: No email found for identifier: $identifier');
        return null;
      }

      // Look up profile picture in Realtime Database using email
      print(
          '🔥 getProfilePicture: Looking up in Realtime Database for email: $email');
      final emailKey = email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      final path = 'profilePictures/$emailKey';

      print('🔥 getProfilePicture: Path: $path');
      print('🔥 getProfilePicture: Email key: $emailKey');

      try {
        print('🔥 getProfilePicture: Checking if path exists...');
        final exists = await FirebaseTools.exists(path);
        print('🔥 getProfilePicture: Path exists: $exists');

        if (exists) {
          print('🔥 getProfilePicture: Loading data from path...');
          final data = await FirebaseTools.load(path);
          print('🔥 getProfilePicture: Data keys: ${data.keys}');
          print(
              '🔥 getProfilePicture: Data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');

          final profilePicture = data['profilePicture'] as String?;
          print(
              '🔥 getProfilePicture: Profile picture found: ${profilePicture != null}, length: ${profilePicture?.length ?? 0}');

          if (profilePicture != null && profilePicture.isNotEmpty) {
            print(
                '🔥 getProfilePicture: SUCCESS - Found profile picture in Realtime Database');
            return profilePicture;
          } else {
            print('🔥 getProfilePicture: Profile picture is null or empty');
          }
        } else {
          print(
              '🔥 getProfilePicture: Path does not exist in Realtime Database');
        }
      } catch (e, stackTrace) {
        print('🔥 getProfilePicture: Realtime Database error: $e');
        print('🔥 getProfilePicture: Stack trace: $stackTrace');
      }

      print(
          '🔥 getProfilePicture: No profile picture found in Realtime Database');
      return null;
    } catch (e) {
      print('🔥 getProfilePicture: ERROR - $e');
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
