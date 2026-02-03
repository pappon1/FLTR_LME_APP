import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Use getter to ensure fresh instance/config
  // GoogleSignIn is now a singleton in v7.x
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  Future<void> _initGoogleSignIn() async {
    await _googleSignIn.initialize();
  }

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Initialize (Required in v7)
      await _initGoogleSignIn();

      // 2. Trigger Google Sign-In flow (authenticate replaces signIn)
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      
      if (googleUser == null) {
        // User cancelled flow
        return null; 
      }
      
      // 3. Obtain auth details (Synchronous getter in v7)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 4. Obtain access token via authorization (Separate step in v7)
      String? accessToken;
      try {
        final authClient = await googleUser.authorizationClient.authorizeScopes(
          [
            'email',
            'https://www.googleapis.com/auth/contacts.readonly',
          ],
        );
        accessToken = authClient.accessToken;
      } catch (e) {
        debugPrint('Authorization error (access token): $e');
        // We might still proceed with just idToken for Firebase if that's enough
      }

      // 5. Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: accessToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Check if user is admin
      await _checkAndCreateUserProfile(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      debugPrint('GOOGLE SIGN IN ERROR: $e');
      rethrow;
    }
  }
 
  /// Check if user exists in Firestore and create/update profile
  Future<void> _checkAndCreateUserProfile(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      // Create new user profile
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'role': 'user', // Default role
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Update last login
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    if (currentUser == null) return false;
    
    try {
      final adminDoc = await _firestore
          .collection('admins')
          .doc(currentUser!.uid)
          .get();
      
      if (adminDoc.exists) {
        return adminDoc.data()?['isActive'] == true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Get user role
  Future<String> getUserRole() async {
    if (currentUser == null) return 'guest';
    
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        return userDoc.data()?['role'] ?? 'user';
      }
      
      return 'user';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'user';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Sign in with email and password (for admin)
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // print('Error signing in with email: $e');
      rethrow;
    }
  }
}
