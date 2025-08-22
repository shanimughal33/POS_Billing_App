import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../utils/auth_utils.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/bill_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/people_repository.dart';
import '../repositories/expense_repository.dart';
import '../utils/refresh_manager.dart';
import '../models/bill.dart';
import '../models/inventory_item.dart';
import '../models/people.dart';
import '../models/expense.dart';
import 'package:intl/intl.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Add form key
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _info;
  bool _loading = false;

  Future<void> _loginWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return; // Validate the form

    setState(() {
      _loading = true;
      _info = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    debugPrint(
      'Login attempt: email="$email", password length: ${password.length}',
    );
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _info = 'Email and password cannot be empty.';
      });
      return;
    }
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      await saveUserUid(userCredential.user!.uid);
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _info = null;
    });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      // Ensure account picker shows by clearing any cached Google session
      try {
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
      } catch (_) {}
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in aborted');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (!mounted) return;
      await saveUserUid(userCredential.user!.uid);
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Color(0xFF0A2342)
          : Colors.white, // White background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animation at the top
              SizedBox(
                height: 200,
                child: Lottie.asset(
                  'assets/loginanimation.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Login',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to your account',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(
                          Icons.email,
                          color: isDark ? Colors.white : Color(0xFF1976D2),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Color(0xFF1976D2).withOpacity(0.15),
                          ),
                        ),
                        fillColor: isDark ? Colors.white10 : Colors.grey[50],
                        filled: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: 14),
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
                    ),
                    const SizedBox(height: 10),
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock,
                          color: isDark ? Colors.white : Color(0xFF1976D2),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Color(0xFF1976D2).withOpacity(0.15),
                          ),
                        ),
                        fillColor: isDark ? Colors.white10 : Colors.grey[50],
                        filled: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                      obscureText: true,
                      style: TextStyle(fontSize: 14),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/forgot_password');
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: isDark ? Colors.white : Color(0xFF1976D2),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _loading
                        ? CircularProgressIndicator(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1976D2),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loginWithEmailPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.white
                                    : Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: StadiumBorder(), // pill-shaped
                                elevation: 2,
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.black.withOpacity(0.15)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: isDark ? Colors.white : Color(0xFF1976D2),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.black.withOpacity(0.15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: FaIcon(
                          FontAwesomeIcons.google,
                          color: Colors.red,
                          size: 22,
                        ),
                        onPressed: _signInWithGoogle,
                        label: Text(
                          'Sign in with Google',
                          style: TextStyle(
                            color: isDark ? Colors.black : Color(0xFF1976D2),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: StadiumBorder(), // pill-shaped
                          elevation: 2,
                          side: BorderSide(
                            color: Color(0xFF1976D2).withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: Text(
                        "Don't have an account? Sign up",
                        style: TextStyle(
                          color: isDark ? Colors.white : Color(0xFF1976D2),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_info != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _info!,
                        style: TextStyle(
                          color: _info!.startsWith('Error')
                              ? Colors.red
                              : Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
