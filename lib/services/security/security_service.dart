import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SecurityService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. Verify PIN ---
  static Future<bool> verifyPin(BuildContext context) async {
    // Show PIN Dialog
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _SecurityPinDialog(),
    ) ?? false;
  }

  // --- 2. Set/Update PIN (Internal) ---
  static Future<void> setPin(String newPin) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'securityPin': newPin,
      }, SetOptions(merge: true));
    }
  }

  // --- 3. Validate PIN against Database ---
  static Future<bool> _validatePinWithServer(String inputPin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('securityPin')) {
        final String storedPin = doc.data()!['securityPin'];
        return storedPin == inputPin;
      }
      // Default PIN if not set
      return inputPin == "1234";
    } catch (e) {
      return false;
    }
  }
}

// --- PIN Dialog UI ---
class _SecurityPinDialog extends StatefulWidget {
  const _SecurityPinDialog();

  @override
  State<_SecurityPinDialog> createState() => _SecurityPinDialogState();
}

class _SecurityPinDialogState extends State<_SecurityPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  bool _showError = false;
  String _errorMessage = "Incorrect PIN";

  Future<void> _verify() async {
    if (_pinController.text.length != 4) return;
    
    setState(() { _isLoading = true; _showError = false; });

    final bool isValid = await SecurityService._validatePinWithServer(_pinController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _showError = true;
        _errorMessage = "Incorrect PIN";
        _pinController.clear();
      });
    }
  }

  void _forgotPin() {
    Navigator.pop(context); // Close PIN dialog
    showDialog(
      context: context, 
      builder: (_) => const _ResetPinAuthDialog()
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin Security'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Enter 4-Digit Security PIN'),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: "",
                hintText: "••••",
                errorText: _showError ? _errorMessage : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                if (val.length == 4) _verify();
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _forgotPin, 
              child: const Text("Forgot/Reset PIN?", style: TextStyle(color: Colors.red))
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        if (_isLoading)
          const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
      ],
    );
  }
}

// --- Reset Auth Dialog ---
class _ResetPinAuthDialog extends StatefulWidget {
  const _ResetPinAuthDialog();

  @override
  State<_ResetPinAuthDialog> createState() => _ResetPinAuthDialogState();
}

class _ResetPinAuthDialogState extends State<_ResetPinAuthDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    _checkProvider();
  }

  void _checkProvider() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (var profile in user.providerData) {
        if (profile.providerId == 'google.com') {
          setState(() => _isGoogleUser = true);
          break;
        }
      }
    }
  }

  Future<void> _reauthenticate() async {
    setState(() => _isLoading = true);
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_isGoogleUser) {
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();
        
        try {
          // Trigger the authentication flow (v7 uses authenticate)
          final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
          
          // Obtain the auth details from the request (synchronous in v7)
          final GoogleSignInAuthentication googleAuth = googleUser.authentication;

          // Obtain access token via authorization (Separate step in v7)
          String? accessToken;
          try {
            final authClient = await googleUser.authorizationClient.authorizeScopes([]);
            accessToken = authClient.accessToken;
          } catch (_) {}

          // Create a new credential
          final AuthCredential credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            accessToken: accessToken,
          );
          
          // Reauthenticate
          await user.reauthenticateWithCredential(credential);

        } catch (e) {
          // If Google Sign In fails, just return (error handled in catch)
          throw FirebaseAuthException(code: 'google-sign-in-failed', message: e.toString());
        }

      } else {
        // Email/Password Logic
        if (_passwordController.text.isEmpty) {
           setState(() => _isLoading = false);
           return;
        }
        final AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!, 
          password: _passwordController.text
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Auth Success
      if (!mounted) return;
      Navigator.pop(context); // Close Auth Dialog
      
      // Open Set New PIN Dialog
      unawaited(showDialog(context: context, builder: (_) => const _SetNewPinDialog()));

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${e.message}'), backgroundColor: Colors.red));
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Security Check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isGoogleUser 
            ? 'Verify with Google to reset PIN.' 
            : 'Enter Admin Password to reset PIN.'),
          const SizedBox(height: 16),
          
          if (!_isGoogleUser)
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _reauthenticate,
          icon: Icon(_isGoogleUser ? FontAwesomeIcons.google : Icons.check, size: 18),
          label: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : Text(_isGoogleUser ? 'Verify with Google' : 'Verify Password'),
        ),
      ],
    );
  }
}

// --- Set New PIN Dialog ---
class _SetNewPinDialog extends StatefulWidget {
  const _SetNewPinDialog();

  @override
  State<_SetNewPinDialog> createState() => _SetNewPinDialogState();
}

class _SetNewPinDialogState extends State<_SetNewPinDialog> {
  final TextEditingController _pin1Controller = TextEditingController();
  final TextEditingController _pin2Controller = TextEditingController();
  
  void _savePin() async {
    if (_pin1Controller.text.length != 4) return;
    if (_pin1Controller.text != _pin2Controller.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match')));
      return;
    }

    await SecurityService.setPin(_pin1Controller.text);
    
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New PIN Set Successfully!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set New PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin1Controller,
            maxLength: 4,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New 4-Digit PIN', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin2Controller,
            maxLength: 4,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm PIN', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        ElevatedButton(onPressed: _savePin, child: const Text('Save PIN'))
      ],
    );
  }
}
