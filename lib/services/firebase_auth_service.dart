import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Email/password sign-in and sign-up can use FirebaseAuth directly in the screens.
  // This service can be used for any shared logic if needed.

  // You can add signOut or other shared methods here if you want.
  Future<void> signOut() async => await _auth.signOut();
}
