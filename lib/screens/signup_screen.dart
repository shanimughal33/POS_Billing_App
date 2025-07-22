import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>(); // Add form key
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _info;
  bool _loading = false;

  Future<void> _signUpWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return; // Validate the form

    setState(() {
      _loading = true;
      _info = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    debugPrint(
      'Signup attempt: email="$email", password length: ${password.length}',
    );
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _info = 'Email and password cannot be empty.';
      });
      return;
    }
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _info = 'Error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _info = 'Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _loading = true;
      _info = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();
      if (googleUser == null) throw Exception('Google sign-in aborted');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _info = 'Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            // Wrap the column with a Form widget
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Title
                Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ).animate().fade(duration: 500.ms).slideY(begin: -0.5),

                const SizedBox(height: 16),
                Text(
                  'Join us to get started',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ).animate().fade(delay: 200.ms),

                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Colors.blue[800]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ).animate().fade(delay: 400.ms).slideX(begin: -0.5),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[800]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ).animate().fade(delay: 500.ms).slideX(begin: -0.5),

                const SizedBox(height: 24),

                // Sign Up Button
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _signUpWithEmailPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 80,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Sign Up'),
                      ).animate().fade(delay: 600.ms).scale(),

                const SizedBox(height: 24),
                const Text('or'),
                const SizedBox(height: 24),

                // Google Sign-Up Button
                ElevatedButton.icon(
                  icon: const FaIcon(
                    FontAwesomeIcons.google,
                    color: Colors.white,
                  ),
                  onPressed: _signUpWithGoogle,
                  label: const Text('Sign up with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ).animate().fade(delay: 700.ms).scale(),

                const SizedBox(height: 24),

                // Login Button
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Text(
                    "Already have an account? Login",
                    style: TextStyle(color: Colors.blue[800]),
                  ),
                ),

                if (_info != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _info!,
                    style: TextStyle(
                      color: _info!.startsWith('Error')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ).animate().slideY(begin: 0.5, duration: 500.ms),
        ),
      ),
    );
  }
}
