import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow (v7 uses authenticate)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      
      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Check if user is admin
      await _checkAndCreateUserProfile(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      // print('Error signing in with Google: $e');
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
      // print('Error checking admin status: $e');
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
      // print('Error getting user role: $e');
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
