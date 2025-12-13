import 'package:firebase_auth/firebase_auth.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!await FirebaseUserTools.exists(result.user!.uid)) {
        await FirebaseUserTools.save(result.user!.uid, {
          "email": result.user?.email,
          "pairToken": result.user?.email,
          "karma": 0,
          "badges": [
            {
              "reason": "Joined Empathy Exchange",
              "time": DateTime.now().toIso8601String(),
              "giver": "system"
            }
          ],
        });
      }
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up with email and password
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirebaseUserTools.save(result.user!.uid, {
        "email": result.user?.email,
        "pairToken": result.user?.email,
        "karma": 0,
        "badges": [
          {
            "reason": "Joined Empathy Exchange",
            "time": DateTime.now().toIso8601String(),
            "giver": "system"
          }
        ],
      });
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential result =
          await _auth.signInWithCredential(credential);
      if (!await FirebaseUserTools.exists(result.user!.uid)) {
        await FirebaseUserTools.save(result.user!.uid, {
          "email": result.user?.email,
          "pairToken": result.user?.email,
          "karma": 0,
          "badges": [
            {
              "reason": "Joined Empathy Exchange",
              "time": DateTime.now().toIso8601String(),
              "giver": "system"
            }
          ],
        });
      }
      return result;
    } catch (e) {
      // Check if it's a user cancellation
      if (e.toString().contains('cancelled') ||
          e.toString().contains('popup_closed') ||
          e.toString().contains('user_cancelled')) {
        return null; // Return null for cancellation instead of throwing
      }
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not allowed.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
